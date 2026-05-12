(in-package :han.host)

(defun argv (&optional (keep-first nil))
  (let ((args sb-ext:*posix-argv*))
    (if keep-first args (rest args))))

(defun getenv (name)
  (sb-ext:posix-getenv name))

(defun quit (&optional (code 0))
  (sb-ext:exit :code code))

(defun %sbcl-command-program-and-arguments (command)
  (cond
    ((and (consp command)
          (stringp (car command)))
     (values (car command) (cdr command)))
    ((stringp command)
     (values "/bin/sh" (list "-c" command)))
    (t
     (error "COMMAND must be a string or a non-empty string list: ~S"
            command))))

(defun run-program-sync
    (command &key input (output :string) (error-output :string)
                  (ignore-error-status t))
  "Run external COMMAND synchronously and return stdout, stderr, and exit code."
  (multiple-value-bind (program arguments)
      (%sbcl-command-program-and-arguments command)
    (let ((temp-files nil))
      (unwind-protect
           (multiple-value-bind (run-input input-temp-files)
               (%prepare-sync-input input temp-files)
             (setf temp-files input-temp-files)
             (multiple-value-bind (run-output output-capture output-temp-files)
                 (%prepare-sync-output output temp-files "han-host-output")
               (setf temp-files output-temp-files)
               (multiple-value-bind (run-error error-capture error-temp-files)
                   (%prepare-sync-output error-output temp-files
                                         "han-host-error" *error-output*)
                 (setf temp-files error-temp-files)
                 (let* ((process (sb-ext:run-program
                                  program
                                  arguments
                                  :search t
                                  :wait t
                                  :input run-input
                                  :output run-output
                                  :error run-error))
                        (exit-code (ignore-errors
                                     (sb-ext:process-exit-code process)))
                        (stdout (%finalize-sync-output output-capture))
                        (stderr (%finalize-sync-output error-capture)))
                   (%check-sync-exit-code command exit-code ignore-error-status)
                   (values stdout stderr exit-code)))))
        (%cleanup-sync-temp-files temp-files)))))

;; Start an external program and return a unified host process handle
(defun run-program (program
                    &key
                      (arguments '())
                      input
                      (directory nil dir-p)
                      (environment nil env-p))
  (when (null (file-exists-p program))
    (error "(Need file path) Program file does not exist: ~A" program))
  (let* ((options (append (list :search t
                                :wait nil
                                :input input
                                :output :stream
                                :error :stream)
                          (when dir-p
                            (list :directory directory))
                          (when env-p
                            (list :environment environment))))
         (proc (apply #'sb-ext:run-program program arguments options)))
    (make-host-process
     :backend :sbcl
     :native-handle proc
     :pid (ignore-errors (sb-ext:process-pid proc))
     :input-stream (ignore-errors (sb-ext:process-input proc))
     :output-stream (ignore-errors (sb-ext:process-output proc))
     :error-stream (ignore-errors (sb-ext:process-error proc)))))

;; Return the current status(:running/:exited/:unknown) of the process
(defun process-status (process)
  (let ((native (host-process-native-handle process)))
    (case (sb-ext:process-status native)
      (:running :running)
      (:stopped :unknown)
      (:signaled :exited)
      (:exited :exited)
      (otherwise :unknown))))

;; Return an integer exit code for exited process, or return NIL
(defun process-exit-code (process)
  (let ((native (host-process-native-handle process)))
    (if (sb-ext:process-alive-p native)
        nil
        (sb-ext:process-exit-code native))))

;; Block until the process ends and return the original process handle
(defun process-wait (process)
  (let ((native (host-process-native-handle process)))
    (sb-ext:process-wait native)
    process))

;; Turn off(not kill) local process-related flows/handles
(defun process-close (process)
  (let ((native (host-process-native-handle process)))
    (ignore-errors (sb-ext:process-close native))
    (%close-stream-safely (host-process-output-stream process))
    (%close-stream-safely (host-process-error-stream process))
    nil))
