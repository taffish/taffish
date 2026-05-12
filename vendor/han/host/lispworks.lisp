(in-package :han.host)

(defun argv (&optional (keep-first nil))
  (let ((args sys:*line-arguments-list*))
    (if keep-first args (rest args))))

(defun getenv (name)
  (lw:environment-variable name))

(defun quit (&optional (code 0))
  (lw:quit :status code))

(defun %lispworks-command-designator (program arguments)
  "LispWorks run-shell-command accepts a string, list or vector command."
  (if arguments
      (cons program arguments)
      program))

(defun %lispworks-sync-command-designator (command)
  (cond
    ((stringp command) command)
    ((and (consp command)
          (stringp (car command)))
     command)
    (t
     (error "COMMAND must be a string or a non-empty string list: ~S"
            command))))

(defun run-program-sync
    (command &key input (output :string) (error-output :string)
                  (ignore-error-status t))
  "Run external COMMAND synchronously and return stdout, stderr, and exit code."
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
               (multiple-value-bind (exit-code signal-code)
                   (system:run-shell-command
                    (%lispworks-sync-command-designator command)
                    :wait t
                    :input run-input
                    :output run-output
                    :error-output run-error)
                 (let ((code (%signal-exit-code exit-code signal-code))
                       (stdout (%finalize-sync-output output-capture))
                       (stderr (%finalize-sync-output error-capture)))
                   (%check-sync-exit-code command code ignore-error-status)
                   (values stdout stderr code))))))
      (%cleanup-sync-temp-files temp-files))))

;; Start an external program and return a unified host process handle
(defun run-program (program
                    &key
                      (arguments '())
                      input
                      (directory nil dir-p)
                      (environment nil env-p))
  (when (null (file-exists-p program))
    (error "(Need file path) Program file does not exist: ~A" program))
  (let ((command (%lispworks-command-designator program arguments)))
    (multiple-value-bind (out-stream err-stream pid)
        (apply #'system:run-shell-command
               command
               (append (list :wait nil
                             :input input
                             :output :stream
                             :error-output :stream
                             :save-exit-status t)
                       (when dir-p
                         (list :current-directory directory))
                       (when env-p
                         (list :environment environment))))
      (make-host-process
       :backend :lispworks
       :native-handle out-stream
       :pid pid
       :input-stream input
       :output-stream out-stream
       :error-stream err-stream))))

;; Return the current status(:running/:exited/:unknown) of the process
(defun process-status (process)
  (if (null (process-exit-code process))
      :running
      :exited))

;; Return an integer exit code for exited process, or return NIL
(defun process-exit-code (process)
  (or (host-process-exit-code process)
      (let ((status-stream (host-process-native-handle process)))
        (when status-stream
          (multiple-value-bind (exit-code signal-code)
              (system:pipe-exit-status status-stream :wait nil)
            (let ((code (%signal-exit-code exit-code signal-code)))
              (when code
                (setf (host-process-exit-code process) code
                      (host-process-signal-code process) signal-code))
              code))))))

;; Block until the process ends and return the original process handle
(defun process-wait (process)
  (let ((status-stream (host-process-native-handle process)))
    (when status-stream
      (multiple-value-bind (exit-code signal-code)
          (system:pipe-exit-status status-stream :wait t)
        (setf (host-process-exit-code process)
              (%signal-exit-code exit-code signal-code)
              (host-process-signal-code process)
              signal-code))))
  process)

;; Turn off(not kill) local process-related flows/handles
(defun process-close (process)
  (%close-stream-safely (host-process-output-stream process))
  (%close-stream-safely (host-process-error-stream process))
  nil)
