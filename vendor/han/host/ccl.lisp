(in-package :han.host)

(defun argv (&optional keep-first)
  (let ((args ccl:*command-line-argument-list*))
    (if keep-first args (rest args))))

(defun %ccl-os-string (string)
  (check-type string string)
  (when (find (code-char 0) string)
    (error "An OS string cannot contain NUL: ~S" string))
  string)

(defun getenv (name)
  (ccl:with-encoded-cstrs :utf-8 ((key (%ccl-os-string name)))
    (let ((value (#_getenv key)))
      (unless (ccl:%null-ptr-p value)
        (ccl::get-encoded-cstring :utf-8 value)))))

(defun quit (&optional (code 0))
  (let ((status (%finish-exit-output code)))
    (ccl:quit status
              :error-handler (lambda (condition)
                               ;; CCL calls FRESH-LINE on its original streams
                               ;; during shutdown, even after Han flushed them.
                               ;; Repeating an optional stderr failure must not
                               ;; turn a completed result into an error.
                               (#__exit
                                (cond ((not (zerop status)) status)
                                      ((and (typep condition 'stream-error)
                                            (eq (stream-error-stream condition) ccl::*stderr*))
                                       0)
                                      (t 1)))))))

(defun %call-with-ccl-cli-interrupt (function)
  ;; CCL sends a terminal interrupt to the debugger hook of the application
  ;; listener, without first signalling the condition to Lisp handlers.
  (let* ((previous *debugger-hook*)
         (ccl::*invoke-debugger-hook-on-interrupt* t)
         (*debugger-hook*
           (lambda (condition hook)
             (declare (ignore hook))
             (if (typep condition 'ccl::interrupt-signal-condition)
                 (signal condition)
                 (when previous (funcall previous condition previous))))))
    (funcall function)))

(defmacro prepare-runtime-io () t)
(defun configure-runtime-io () t)
(defun current-process-id () (#_getpid))
(defun standard-input-terminal-p () (= 1 (#_isatty 0)))
(defun standard-error-terminal-p () (= 1 (#_isatty 2)))

(defun %literal-file-pathname (path)
  (ccl:native-to-pathname path))

(defun %literal-file-stat (name)
  (ccl:with-encoded-cstrs :utf-8 ((path name))
    (ccl:rlet ((st :stat))
      ;; Use the kernel's matching lstat ABI, as in CCL's own %%LSTAT.
      (let ((result (ccl::int-errno-ffcall
                     (ccl::%kernel-import target::kernel-import-lisp-lstat)
                     :address path :address st :int)))
        (if (minusp result) result
            (values (ccl:pref st :stat.st_mode) (ccl:pref st :stat.st_dev)
                    (ccl:pref st :stat.st_ino)))))))

(defun %literal-rename-errno (source target)
  (ccl:with-encoded-cstrs :utf-8 ((old source) (new target))
    (if (zerop (#_rename old new)) 0 (- (ccl::%get-errno)))))

(defun %open-lock-file (path flags)
  (ccl:with-encoded-cstrs :utf-8 ((name (%ccl-os-string path)))
    (let ((fd (ccl::fd-open-path name flags #o666)))
      (if (minusp fd) (values nil (- fd)) fd))))

(defun %try-exclusive-file-lock (fd)
  (unless (zerop (ccl:external-call "flock" :int fd :int (logior #$LOCK_EX #$LOCK_NB) :int))
    (- (ccl::%get-errno))))

(defun %close-lock-file (fd)
  (ccl::fd-close fd))

(defun append-utf8-line (path line)
  (let* ((file (%prepare-native-file path))
         (octets (ccl:encode-string-to-octets (%utf8-line-string line)
                                              :external-format :utf-8)))
    (multiple-value-bind (fd errno)
        (%open-lock-file (%native-open-name path)
                         (logior #$O_WRONLY #$O_CREAT #$O_APPEND #$O_CLOEXEC))
      (unless fd (error "Cannot open append path ~A (errno ~D)." file errno))
      (unwind-protect
           (ccl:with-pointer-to-ivector (buffer octets)
             (loop with offset = 0
                   while (< offset (length octets))
                   for n = (ccl::fd-write fd (ccl:%inc-ptr buffer offset)
                                          (- (length octets) offset))
                   do (unless (plusp n)
                        (error "Cannot write append path ~A (result ~D)." file n))
                      (incf offset n)))
        (%close-lock-file fd)))
    file))

;; CCL 1.14's Unix RUN-PROGRAM lacks child chdir and reports exec failures as
;; ordinary exit 71. Spawn directly and hand the PID to CCL's normal monitor.
(defun %ccl-check-spawn (result operation)
  (unless (zerop result)
    (error "~A failed (errno ~D)." operation result)))

(defun %ccl-spawn-pid (argv environment directory descriptors search-path)
  ;; Darwin uses opaque pointers for the two POSIX spawn objects. Linux's
  ;; file-actions structure has a different size, provided by CCL's headers.
  (ccl:rlet ((actions #+darwin :address #+linux :posix_spawn_file_actions_t)
             #+darwin (attributes :address)
             (pid :pid_t))
    (%ccl-check-spawn (ccl:external-call "posix_spawn_file_actions_init"
                                        :address actions :int)
                      "Initializing child file actions")
    (unwind-protect
         (progn
           (when directory
             (let ((chdir (or (ccl:foreign-symbol-address "posix_spawn_file_actions_addchdir")
                              (ccl:foreign-symbol-address "posix_spawn_file_actions_addchdir_np")
                              (error "The system cannot set a child working directory."))))
               (ccl:with-encoded-cstrs :utf-8 ((path directory))
                 (%ccl-check-spawn (ccl:ff-call chdir :address actions :address path :int)
                                   "Setting child directory"))))
           (loop for fd in descriptors for target from 0
                 do (%ccl-check-spawn
                     (ccl:external-call "posix_spawn_file_actions_adddup2"
                                        :address actions :int fd :int target :int)
                     "Setting child standard descriptor"))
           #+linux
           (let ((closefrom (ccl:foreign-symbol-address "posix_spawn_file_actions_addclosefrom_np")))
             (when closefrom
               (%ccl-check-spawn (ccl:ff-call closefrom :address actions :int 3 :int)
                                 "Closing inherited descriptors")))
           #+darwin
           (%ccl-check-spawn (ccl:external-call "posix_spawnattr_init" :address attributes :int)
                             "Initializing child attributes")
           (unwind-protect
                (progn
                  #+darwin
                  (%ccl-check-spawn (ccl:external-call "posix_spawnattr_setflags"
                                                       :address attributes :short #x4000 :int)
                                    "Setting POSIX_SPAWN_CLOEXEC_DEFAULT")
                  (ccl:with-string-vector (args argv :utf-8)
                    (ccl:with-string-vector (env (unless (eq environment t) environment) :utf-8)
                      (let ((spawn (ccl:foreign-symbol-address
                                    (if search-path "posix_spawnp" "posix_spawn")))
                            (envp (if (eq environment t)
                                      (ccl:%get-ptr (ccl:foreign-symbol-address "environ"))
                                      env)))
                        (%ccl-check-spawn
                         (ccl:ff-call spawn :address pid :address (ccl:%get-ptr args)
                                      :address actions :address #+darwin attributes
                                                                #+linux (ccl:%null-ptr)
                                      :address args :address envp :int)
                         (first argv))))))
             #+darwin (ccl:external-call "posix_spawnattr_destroy" :address attributes :int))
           (ccl:pref pid :pid_t))
      (ccl:external-call "posix_spawn_file_actions_destroy" :address actions :int))))

(defun %ccl-duplicate-fd (fd)
  ;; Even if a standard descriptor was closed before launch, no redirection
  ;; can clobber a later dup2 source. The original descriptor stays owned by
  ;; its caller until the duplication succeeds.
  (let ((copy (#_fcntl fd #$F_DUPFD_CLOEXEC :int 3)))
    (when (minusp copy)
      (error "Cannot duplicate child descriptor ~D (errno ~D)." fd (- (ccl::%get-errno))))
    copy))

(defun %ccl-pipe ()
  #+darwin (ccl::pipe)
  #+linux
  (ccl:rlet ((ends (:array :int 2)))
    (unless (zerop (ccl:external-call "pipe2" :address ends :int #$O_CLOEXEC :int))
      (error "Cannot create child pipe (errno ~D)." (- (ccl::%get-errno))))
    (values (ccl:paref ends (:array :int) 0) (ccl:paref ends (:array :int) 1))))

(defun %ccl-spawn (argv environment directory input output error-output &key search-path)
  (mapc #'%ccl-os-string argv)
  (unless (eq environment t)
    (dolist (entry environment)
      (unless (plusp (or (position #\= (%ccl-os-string entry)) 0))
        (error "Expected NAME=VALUE in environment, got ~S." entry))))
  (when directory (setf directory (%ccl-os-string (%native-open-name directory))))
  (let ((fds nil) (streams nil) (complete nil))
    (labels ((own (fd) (push fd fds) fd)
             (close-owned (fd)
               (ccl::fd-close fd)
               (setf fds (delete fd fds)))
             (open-fd (path flags)
               (multiple-value-bind (fd errno)
                   (%open-lock-file path (logior flags #$O_CLOEXEC))
                 (unless fd (error "Cannot open child redirection ~A (errno ~D)." path errno))
                 (own fd)
                 (if (< fd 3) (prog1 (own (%ccl-duplicate-fd fd)) (close-owned fd)) fd)))
             (pipe-ends (target)
               (multiple-value-bind (read write) (%ccl-pipe)
                 (own read)
                 (own write)
                 (let* ((stdin (zerop target))
                        (child (own (%ccl-duplicate-fd (if stdin read write))))
                        (parent (own (%ccl-duplicate-fd (if stdin write read))))
                        (stream (ccl::make-fd-stream parent :direction (if stdin :output :input)
                                                    :encoding :utf-8 :sharing :lock :auto-close t)))
                   (setf fds (delete parent fds))
                   (push stream streams)
                   (close-owned read)
                   (close-owned write)
                   (values child stream))))
             (channel (spec target)
               (cond ((eq spec :stream) (pipe-ends target))
                     ((null spec) (open-fd "/dev/null" (if (zerop target) #$O_RDONLY #$O_WRONLY)))
                     ((integerp spec) (own (%ccl-duplicate-fd spec)))
                     (t (let ((path (%native-open-name spec)))
                          ;; Input filenames are relative to the child's cwd.
                          (when (and directory (zerop target)
                                     (not (eql (position #\/ path) 0)))
                            (setf path (concatenate 'string directory "/" path)))
                          (open-fd path (if (zerop target) #$O_RDONLY
                                            (logior #$O_WRONLY #$O_CREAT #$O_EXCL))))))))
      (unwind-protect
           (multiple-value-bind (in in-stream) (channel input 0)
             (multiple-value-bind (out out-stream) (channel output 1)
               (multiple-value-bind (err err-stream) (channel error-output 2)
                 (let* ((native (ccl::make-external-process
                                 :args argv :%status :running :token (list 0)
                                 :input in-stream :output out-stream :error err-stream
                                 :external-format (ccl::normalize-external-format t :utf-8)))
                        (pid (%ccl-spawn-pid argv environment directory
                                             (list in out err) search-path)))
                   (setf (ccl::external-process-pid native) pid)
                   (unwind-protect
                        (progn
                          (ccl::add-external-process native)
                          (ccl:process-run-function "Han child monitor"
                                                    #'ccl::monitor-external-process native)
                          (setf complete t)
                          native)
                     (unless complete
                       (#_kill pid #$SIGKILL)
                       (ccl::monitor-external-process native)))))))
        (mapc #'ccl::fd-close fds)
        (unless complete (mapc #'%close-stream-safely streams))))))

(defun %ccl-process-code (native)
  (multiple-value-bind (status code) (ccl:external-process-status native)
    (when (integerp code)
      (case status (:exited code) (:signaled (+ 128 code))))))

(defun %ccl-wait (native)
  (ccl:process-wait "Waiting for child exit" #'%ccl-process-code native)
  (%ccl-process-code native))

(defun run-program-sync
    (command &key input (output :string) (error-output :string) (ignore-error-status t))
  (when (member :stream (list input output error-output))
    (error "Synchronous I/O cannot return a :STREAM pipe."))
  (let ((argv (etypecase command
                (string (list "/bin/sh" "-c" command))
                (cons command)))
        (temp-files nil))
    (unwind-protect
         (multiple-value-bind (in input-files) (%prepare-sync-input input temp-files)
           (setf temp-files input-files)
           (multiple-value-bind (out stdout output-files)
               (%prepare-sync-output output temp-files "han-host-output")
             (setf temp-files output-files)
             (multiple-value-bind (err stderr error-files)
                 (%prepare-sync-output error-output temp-files "han-host-error" *error-output*)
               (setf temp-files error-files)
               (let ((exit (%ccl-wait (%ccl-spawn argv t nil in out err :search-path t)))
                     (output-value (%finalize-sync-output stdout))
                     (error-value (%finalize-sync-output stderr)))
                 (%check-sync-exit-code command exit ignore-error-status)
                 (values output-value error-value exit)))))
      (%cleanup-sync-temp-files temp-files))))

(defun %ccl-spool-input (stream path)
  (if (subtypep (stream-element-type stream) 'character)
      (%copy-stream-to-file stream path)
      (with-open-file (out path :direction :output :element-type '(unsigned-byte 8)
                                :if-exists :error :if-does-not-exist :create)
        (loop for byte = (read-byte stream nil nil)
              while byte do (write-byte byte out))))
  path)

(defun run-program (program &key arguments input directory (environment nil env-p))
  (let* ((argv (cons (%native-open-name program) arguments))
         (in (if (eq input t) *standard-input* input))
         (fd (when (streamp in)
               (let ((device (ccl:stream-device in :input)))
                 (when (typep device '(integer 0)) device))))
         ;; A Lisp file stream may already have read past its logical position
         ;; into its buffer. Preserve its unread input, including UNREAD-CHAR.
         ;; Terminals and live descriptors must remain available to the child.
         (spool (when (and (streamp in) (or (null fd) (eq :file (ccl::%unix-fd-kind fd))))
                  (%host-temp-file "han-host-input" "tmp"))))
    (unwind-protect
         (let ((native (%ccl-spawn argv (if env-p environment t) directory
                                   (cond (spool (%ccl-spool-input in spool)) (fd fd) (t in))
                                   :stream :stream)))
           (make-host-process :backend :ccl :native-handle native
                              :pid (ccl:external-process-id native)
                              :input-stream (ccl:external-process-input-stream native)
                              :output-stream (ccl:external-process-output-stream native)
                              :error-stream (ccl:external-process-error-stream native)))
      (%delete-file-safely spool))))

(defun process-status (process)
  (case (ccl:external-process-status (host-process-native-handle process))
    (:running :running) ((:exited :signaled) :exited) (otherwise :unknown)))

(defun process-exit-code (process)
  (%ccl-process-code (host-process-native-handle process)))

(defun process-wait (process)
  (%ccl-wait (host-process-native-handle process))
  process)

(defun process-close (process)
  (%close-stream-safely (host-process-input-stream process))
  (%close-stream-safely (host-process-output-stream process))
  (%close-stream-safely (host-process-error-stream process))
  nil)
