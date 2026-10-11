(in-package :han.host)

(define-condition unsupported-host-function (error)
  ((function-name :initarg :function-name :reader unsupported-host-function-name)
   (implementation :initarg :implementation :reader unsupported-host-implementation))
  (:report (lambda (c s)
             (format s
                     "han.host: ~A is not implemented for Lisp implementation ~A.~%~
                      Supported implementations currently include[~A]: ~A."
                     (unsupported-host-function-name c)
                     (unsupported-host-implementation c)
                     (length *supported-implementations*)
                     (supported-implementations-string)))))

(defun signal-unsupported-host-function (fn)
  (error 'unsupported-host-function
         :function-name fn
         :implementation (lisp-implementation-type)))

(defun argv (&optional keep-first)
  (declare (ignore keep-first))
  (signal-unsupported-host-function 'argv))

(defun getenv (name)
  (declare (ignore name))
  (signal-unsupported-host-function 'getenv))

(defun quit (&optional code)
  (declare (ignore code))
  (signal-unsupported-host-function 'quit))

(defmacro prepare-runtime-io ()
  '(signal-unsupported-host-function 'prepare-runtime-io))

(defun configure-runtime-io ()
  (signal-unsupported-host-function 'configure-runtime-io))

(defun standard-input-terminal-p ()
  (signal-unsupported-host-function 'standard-input-terminal-p))

(defun standard-error-terminal-p ()
  (signal-unsupported-host-function 'standard-error-terminal-p))

(defun current-process-id ()
  (signal-unsupported-host-function 'current-process-id))

(defun append-utf8-line (path line)
  (declare (ignore path line))
  (signal-unsupported-host-function 'append-utf8-line))

(defun run-program-sync
    (command &key input output error-output ignore-error-status)
  (declare (ignore command input output error-output ignore-error-status))
  (signal-unsupported-host-function 'run-program-sync))

(defun run-program (program
                    &key
                      arguments
                      input
                      directory
                      environment)
  (declare (ignore program arguments input directory environment))
  (signal-unsupported-host-function 'run-program))

(defun process-status (process)
  (declare (ignore process))
  (signal-unsupported-host-function 'process-status))

(defun process-exit-code (process)
  (declare (ignore process))
  (signal-unsupported-host-function 'process-exit-code))

(defun process-wait (process)
  (declare (ignore process))
  (signal-unsupported-host-function 'process-wait))

(defun process-close (process)
  (declare (ignore process))
  (signal-unsupported-host-function 'process-close))
