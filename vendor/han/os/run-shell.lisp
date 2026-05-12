(in-package :han.os)

(defun %lines-to-string (lines)
  (format nil "~{~A~%~}" lines))

(defun %string-to-lines (string)
  (with-input-from-string (in (or string ""))
    (keep-read-line in)))

(defun escape-sh-token (value)
  "Return VALUE escaped as one POSIX shell token."
  (han.host:escape-sh-token value))

(defun run-program (command &key input (output :string) (error-output :string)
                            (ignore-error-status t))
  "Run external COMMAND synchronously and return stdout, stderr, and exit code."
  (han.host:run-program-sync
   command
   :input input
   :output output
   :error-output error-output
   :ignore-error-status ignore-error-status))

(defun run-shell-command
    (command &key (wait t) (lines t) shell)
  "Run shell COMMAND.

When WAIT is true:
  - wait for the command to finish
  - if LINES is true, return stdout-lines, stderr-lines and exit-code
  - otherwise return stdout-string, stderr-string and exit-code

When WAIT is false:
  - return stdout-stream, stderr-stream, NIL, and process

If SHELL is NIL, try bash first, then sh."
  (let* ((shell-path (or shell
                         (find-executable "bash")
                         (find-executable "sh")
                         (error "No shell executable found."))))
    (unless (han.host:file-exists-p shell-path)
      (error "Shell executable does not exist: ~A" shell-path))
    (if wait
        ;; han.host drains process output while waiting, avoiding pipe-buffer
        ;; deadlocks for commands that produce large stdout/stderr.
        (multiple-value-bind (out err exit-code)
            (han.host:run-program-sync
             (list shell-path "-c" command)
             :output :string
             :error-output :string
             :ignore-error-status t)
          (if lines
              (values (%string-to-lines out)
                      (%string-to-lines err)
                      exit-code)
              (values out err exit-code)))
        (let* ((process (han.host:run-program shell-path
                                              :arguments (list "-c" command)))
               (out-stream (han.host:host-process-output-stream process))
               (err-stream (han.host:host-process-error-stream  process)))
          (values out-stream err-stream nil process)))))
