(in-package :han.host)

(ffi:clines "#include <errno.h>" "#include <fcntl.h>" "#include <stdio.h>" "#include <sys/file.h>"
            "#include <sys/stat.h>" "#include <unistd.h>")

;; ECL returns argv and getenv as base strings containing the original bytes.
(defun %ecl-decode-os-string (bytes)
  (when bytes
    ;; A UTF-8 string has at most one character per byte. Read it in one
    ;; pass: ECL 26.5.5's OCTETS-TO-STRING miscounts long decoded strings.
    (with-open-stream (input (ext:make-sequence-input-stream bytes :external-format :utf-8))
      (let* ((buffer (make-string (length bytes) :element-type 'character))
             (end (read-sequence buffer input)))
        (if (= end (length buffer)) buffer (subseq buffer 0 end))))))

(defun %ecl-c-string (text)
  (when (find (code-char 0) text)
    (error "An OS string cannot contain NUL: ~S" text))
  (map 'simple-base-string #'code-char
       (ext:string-to-octets text :external-format :utf-8)))

(defun argv (&optional keep-first)
  (let ((args (ext:command-args)))
    (mapcar #'%ecl-decode-os-string (if keep-first args (rest args)))))

(defun getenv (name)
  (%ecl-decode-os-string (ext:getenv (%ecl-c-string name))))

(defun quit (&optional (code 0))
  (ext:quit (%finish-exit-output code)))

(defmacro prepare-runtime-io () t)

(defun configure-runtime-io () t)

(defun current-process-id () (ext:getpid))

(defun %ecl-isatty (fd)
  (plusp (ffi:c-inline (fd) (:int) :int "isatty(#0)" :one-liner t)))

(defun standard-input-terminal-p () (%ecl-isatty 0))
(defun standard-error-terminal-p () (%ecl-isatty 2))

(defun %literal-file-stat (name)
  (ffi:c-inline ((%ecl-c-string name)) (:cstring)
                (values :int :uint64-t :uint64-t)
    "{ struct stat st;
       if (lstat(#0, &st) < 0) {
         @(return 0) = -errno; @(return 1) = 0; @(return 2) = 0;
       } else {
         @(return 0) = st.st_mode;
         @(return 1) = st.st_dev;
         @(return 2) = st.st_ino;
       } }"))

(defun %literal-rename-errno (source target)
  (ffi:c-inline ((%ecl-c-string source) (%ecl-c-string target)) (:cstring :cstring)
                :int "rename(#0, #1) == 0 ? 0 : errno" :one-liner t))

(defun %prepare-native-file (path)
  ;; ECL rejects wildcard characters in OPEN and ENSURE-DIRECTORIES-EXIST,
  ;; even when present as literal strings in MAKE-PATHNAME components.
  (let ((name (%native-open-name path)))
    (do ((slash (position #\/ name) (position #\/ name :start (1+ slash))))
        ((null slash))
      (when (and (plusp slash) (char/= (char name (1- slash)) #\/))
        (let* ((parent (subseq name 0 slash))
               (errno (ffi:c-inline ((%ecl-c-string parent)) (:cstring) :int
                       "{ struct stat st;
                          if (mkdir(#0, 0777) == 0) @(return) = 0;
                          else if (errno != EEXIST) @(return) = errno;
                          else if (stat(#0, &st) < 0) @(return) = errno;
                          else @(return) = S_ISDIR(st.st_mode) ? 0 : ENOTDIR; }")))
          (unless (zerop errno)
            (error "Cannot create parent directory ~A (errno ~D)." parent errno)))))
    (pathname path)))

(defun %open-lock-file (path flags)
  (let ((fd (ffi:c-inline ((%ecl-c-string path) flags) (:cstring :int) :int
             "{ int fd = open(#0, #1, 0666); @(return) = fd < 0 ? -errno : fd; }")))
    (if (minusp fd) (values nil (- fd)) fd)))

(defun %try-exclusive-file-lock (fd)
  (let ((errno (ffi:c-inline (fd) (:int) :int
                "(flock(#0, LOCK_EX | LOCK_NB) == 0 ? 0 : errno)" :one-liner t)))
    (unless (zerop errno) errno)))

(defun %close-lock-file (fd)
  (ffi:c-inline (fd) (:int) :int "close(#0)" :one-liner t))

(defun append-utf8-line (path line)
  (let* ((file (%prepare-native-file path))
         (octets (ext:string-to-octets (%utf8-line-string line) :external-format :utf-8))
         (errno (ffi:c-inline ((%ecl-c-string (%native-open-name path)) octets)
                    (:cstring :object) :int
                  "{ int fd = open(#0, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0666);
                     int err = fd < 0 ? errno : 0;
                     size_t offset = 0, len = ecl_length(#1);
                     while (!err && offset < len) {
                       ssize_t n = write(fd, #1->vector.self.b8 + offset, len - offset);
                       if (n > 0) offset += n;
                       else if (n == 0 || errno != EINTR) err = n == 0 ? EIO : errno;
                     }
                     if (fd >= 0 && close(fd) < 0 && !err) err = errno;
                     @(return) = err; }")))
    (unless (zerop errno)
      (error "Cannot append to ~A (errno ~D)." file errno))
    file))

;; ECL's RUN-PROGRAM calls exec in the child and reports exec failures as
;; ordinary exits. POSIX spawn reports these failures to the caller, supports
;; an independent child directory and accepts the environment as UTF-8 bytes.
(ffi:clines
 "#include <spawn.h>" "#include <dlfcn.h>"
 "#ifdef __linux__" "extern int pipe2(int [2], int);" "#endif"
 "#ifdef __APPLE__" "#include <crt_externs.h>"
 "#define HAN_ENVIRON (*_NSGetEnviron())" "#else"
 "extern char **environ;" "#define HAN_ENVIRON environ" "#endif"
 "static char **han_vector(cl_object list) {
    char **v = ecl_alloc((1 + ecl_length(list)) * sizeof(*v));
    size_t i = 0;
    for (; list != ECL_NIL; list = ECL_CONS_CDR(list))
      v[i++] = ecl_base_string_pointer_safe(ECL_CONS_CAR(list));
    v[i] = NULL;
    return v;
  }"
 "static int han_pipe(int fds[2]) {
    int p[2];
#ifdef __linux__
    if (pipe2(p, O_CLOEXEC) < 0) return errno;
#else
    if (pipe(p) < 0) return errno;
#endif
    /* Keep both temporary endpoints distinct from stdin/stdout/stderr,
       including when the caller has a closed standard descriptor. */
    for (int i = 0; i < 2; i++) {
      fds[i] = fcntl(p[i], F_DUPFD_CLOEXEC, 3);
      if (fds[i] < 0) {
        int err = errno;
        close(p[0]); close(p[1]);
        if (i != 0) close(fds[0]);
        return err;
      }
    }
    close(p[0]); close(p[1]);
    return 0;
  }"
 "static cl_object han_spawn(cl_object args, cl_object environment,
                             cl_object dir, cl_object in, cl_object out, cl_object errout,
                             int search_path) {
    char **argv = han_vector(args);
    char **envp = environment == ECL_T ? HAN_ENVIRON : han_vector(environment);
    cl_object streams[3] = {in, out, errout};
    int pipes[3][2] = {{-1,-1},{-1,-1},{-1,-1}};
    int retained[3] = {-1,-1,-1};
    int files[3] = {-1,-1,-1};
    pid_t pid;
    posix_spawn_file_actions_t actions;
    int err = posix_spawn_file_actions_init(&actions);
    if (err) return ecl_make_fixnum(-err);
    if (dir != ECL_NIL) {
      typedef int (*change_dir)(posix_spawn_file_actions_t *, const char *);
      change_dir cd = (change_dir)dlsym(RTLD_DEFAULT, \"posix_spawn_file_actions_addchdir\");
      if (!cd) cd = (change_dir)dlsym(RTLD_DEFAULT, \"posix_spawn_file_actions_addchdir_np\");
      err = cd ? cd(&actions, ecl_base_string_pointer_safe(dir)) : ENOSYS;
    }
    for (int i = 0; !err && i < 3; i++) {
      if (streams[i] == ECL_T) {
        int p[2];
        err = han_pipe(p);
        if (err) break;
        pipes[i][0] = p[0]; pipes[i][1] = p[1];
        int child = i == 0 ? 0 : 1;
        retained[i] = p[1-child];
        err = posix_spawn_file_actions_adddup2(&actions, p[child], i);
      } else if (ECL_FIXNUMP(streams[i])) {
        err = posix_spawn_file_actions_adddup2(&actions, ecl_fixnum(streams[i]), i);
      } else if (i != 0 && streams[i] != ECL_NIL) {
        /* Darwin's spawnp may replay the actions for every PATH candidate.
           Open each output exactly once, still refusing to overwrite a file. */
        int fd = open(ecl_base_string_pointer_safe(streams[i]),
                      O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0666);
        if (fd < 0) { err = errno; break; }
        if (fd < 3) {
          files[i] = fcntl(fd, F_DUPFD_CLOEXEC, 3);
          if (files[i] < 0) err = errno;
          close(fd);
        } else files[i] = fd;
        if (!err) err = posix_spawn_file_actions_adddup2(&actions, files[i], i);
      } else {
        const char *path = streams[i] == ECL_NIL ? \"/dev/null\" : ecl_base_string_pointer_safe(streams[i]);
        err = posix_spawn_file_actions_addopen(&actions, i, path, i == 0 ? O_RDONLY : O_WRONLY, 0);
      }
    }
    posix_spawnattr_t *attributes = NULL;
#ifdef POSIX_SPAWN_CLOEXEC_DEFAULT
    /* Darwin has no pipe2. Inherit only descriptors installed by our actions. */
    posix_spawnattr_t attr;
    if (!err && !(err = posix_spawnattr_init(&attr))) {
      attributes = &attr;
      err = posix_spawnattr_setflags(attributes, POSIX_SPAWN_CLOEXEC_DEFAULT);
    }
#endif
    if (!err) {
      if (search_path) err = posix_spawnp(&pid, argv[0], &actions, attributes, argv, envp);
      else err = posix_spawn(&pid, argv[0], &actions, attributes, argv, envp);
    }
    if (attributes) posix_spawnattr_destroy(attributes);
    posix_spawn_file_actions_destroy(&actions);
    for (int i = 0; i < 3; i++) {
      if (files[i] >= 0) close(files[i]);
      for (int j = 0; j < 2; j++)
        if (pipes[i][j] >= 0 && (err || pipes[i][j] != retained[i])) close(pipes[i][j]);
    }
    if (err) return ecl_make_fixnum(-err);
    return cl_list(4, ecl_make_fixnum(pid), ecl_make_fixnum(retained[0]),
                   ecl_make_fixnum(retained[1]), ecl_make_fixnum(retained[2]));
  }")

(defun %ecl-stream-designator (value)
  (etypecase value
    (null nil)
    ((eql :stream) t)
    ((or pathname string) (%ecl-c-string (namestring value)))
    (stream
     (let ((fd (ext:file-stream-fd value)))
       (unless (and (integerp fd) (not (minusp fd)))
         (error "No file descriptor for child stream ~S." value))
       fd))))

(defun %ecl-spawn (argv env dir in out err &key search-path)
  (dolist (arg argv) (check-type arg string))
  (unless (eq env t)
    (dolist (entry env)
      (unless (and (stringp entry) (plusp (or (position #\= entry) 0)))
        (error "Expected NAME=VALUE in environment, got ~S." entry))))
  (let* ((args (mapcar #'%ecl-c-string argv))
         (environment (if (eq env t) t (mapcar #'%ecl-c-string env)))
         (directory (when dir
                      (%ecl-c-string (namestring (merge-pathnames (%directory-pathname dir)
                                                                (working-directory-pathname))))))
         (input (%ecl-stream-designator in))
         (output (%ecl-stream-designator out))
         (error-output (%ecl-stream-designator err))
         (native (ext:make-external-process))
         (result (ffi:c-inline (args environment directory input output error-output
                                     (if search-path 1 0))
                               (:object :object :object :object :object :object :int) :object
                               "han_spawn(#0,#1,#2,#3,#4,#5,#6)" :one-liner t)))
    (when (integerp result)
      (error "Cannot launch ~S (errno ~D)." (first argv) (- result)))
    (let ((pending (rest result))
          (streams nil)
          (complete nil))
      (setf (ext:external-process-pid native) (first result))
      (ext:set-finalizer native #'ext::finalize-external-process)
      (unwind-protect
           (flet ((stream-for (direction)
                    (let ((fd (first pending)))
                      (prog1 (when (plusp fd)
                               (let ((s (ext:make-stream-from-fd
                                         fd direction :element-type 'character
                                         :external-format :utf-8)))
                                 (push s streams)
                                 s))
                        (pop pending)))))
             (setf (ext:external-process-input native) (stream-for :output)
                   (ext:external-process-output native) (stream-for :input)
                   (ext:external-process-error-stream native) (stream-for :input)
                   complete t)
             native)
        (unless complete
          (dolist (fd pending) (when (plusp fd) (%close-lock-file fd)))
          (mapc #'%close-stream-safely streams))))))

(defun %ecl-process-code (status code)
  (case status
    (:exited code)
    (:signaled (+ 128 code))))

(defun %ecl-wait (native)
  (do () (nil)
    (multiple-value-bind (status code) (ext:external-process-wait native t)
      (case status
        ((:exited :signaled) (return (%ecl-process-code status code)))
        ((:error :abort) (error "ECL could not wait for the child (~S)." status))))))

(defun run-program-sync
    (command &key input (output :string) (error-output :string) (ignore-error-status t))
  (when (or (eq input :stream) (eq output :stream) (eq error-output :stream))
    (error "Synchronous I/O cannot return a :STREAM pipe."))
  (let* ((argv (etypecase command
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
               (let ((native (%ecl-spawn argv t nil in out err :search-path t)))
                 (let ((exit (%ecl-wait native))
                       (output-value (%finalize-sync-output stdout))
                       (error-value (%finalize-sync-output stderr)))
                   (%check-sync-exit-code command exit ignore-error-status)
                   (values output-value error-value exit))))))
      (%cleanup-sync-temp-files temp-files))))

(defun run-program (program &key arguments input directory (environment nil env-p))
  (let* ((argv (cons (%native-open-name program) arguments))
         (in (if (eq input t) *standard-input* input))
         ;; Preserve non-file-backed character streams supplied by callers.
         (spool (when (and (streamp in) (not (typep in 'file-stream)))
                  (%host-temp-file "han-host-input" "tmp"))))
    (unwind-protect
         (let ((native (%ecl-spawn argv (if env-p environment t) directory
                                   (if spool (%copy-stream-to-file in spool) in)
                                   :stream :stream)))
           (make-host-process :backend :ecl :native-handle native
                              :pid (ext:external-process-pid native)
                              :input-stream (ext:external-process-input native)
                              :output-stream (ext:external-process-output native)
                              :error-stream (ext:external-process-error-stream native)))
      (%delete-file-safely spool))))

(defun process-status (process)
  (case (ext:external-process-status (host-process-native-handle process))
    ((:running :resumed) :running)
    ((:exited :signaled) :exited)
    (otherwise :unknown)))

(defun process-exit-code (process)
  (multiple-value-call #'%ecl-process-code
    (ext:external-process-status (host-process-native-handle process))))

(defun process-wait (process)
  (%ecl-wait (host-process-native-handle process))
  process)

(defun process-close (process)
  (%close-stream-safely (host-process-input-stream process))
  (%close-stream-safely (host-process-output-stream process))
  (%close-stream-safely (host-process-error-stream process))
  nil)
