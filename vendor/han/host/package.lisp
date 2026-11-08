(defpackage :han.host
  (:use :cl)
  (:export
   :help
   :version

   ;; condition
   :unsupported-host-function

   ;; parameters
   :*supported-implementations*

   ;; common functions
	   :argv
	   :getenv
	   :quit
	   :prepare-runtime-io
	   :configure-runtime-io
	   :standard-input-terminal-p
	   :standard-error-terminal-p
	   :current-process-id
	   :append-utf8-line
	   :call-with-exclusive-file-lock
	   :cwd
	   :file-exists-p
	   :directory-exists-p
	   :directory-files
	   :subdirectories
	   :copy-file
	   :delete-directory-tree
	   :temporary-directory
	   :escape-sh-token
	   :with-character-output-to-string

	   ;; process handle
   :host-process
   :make-host-process
   :host-process-backend
   :host-process-native-handle
   :host-process-pid
   :host-process-input-stream
   :host-process-output-stream
   :host-process-error-stream

	   ;; process api
	   :run-program
	   :run-program-sync
	   :process-status
	   :process-exit-code
	   :process-wait
   :process-close))

(in-package :han.host)

(defun %get-help-string ()
  "han.host v0.1.0

Purpose:
  Provide a small host-implementation portability layer for TAFFISH.
  It hides SBCL/LispWorks differences behind one process/env/argv API.

Common usage:
  (han.host:argv)
	  (han.host:getenv \"HOME\")
	  (han.host:cwd)
	  (han.host:quit 0)
	  (han.host:prepare-runtime-io)
	  (han.host:configure-runtime-io)
	  (han.host:standard-input-terminal-p)
	  (han.host:standard-error-terminal-p)
	  (han.host:current-process-id)
	  (han.host:append-utf8-line path line)
	  (han.host:call-with-exclusive-file-lock lock-path function :timeout 5)
	  (han.host:file-exists-p path)
	  (han.host:escape-sh-token token)
	  (han.host:run-program \"/bin/sh\" :arguments '(\"-c\" \"echo hi\"))
	  (han.host:run-program-sync '(\"git\" \"status\") :output :string)

Terminal query:
  standard-error-terminal-p  true only when process stderr (fd 2) is a terminal
  This read-only query does not inspect a rebound *error-output*, read stdin,
  or start a subprocess. A non-terminal or closed stderr returns NIL.

Process API:
	  append-utf8-line    append UTF-8 bytes and one newline
	  call-with-exclusive-file-lock  serialize cooperating processes on one lock file
	  run-program          start a child process
	  run-program-sync     run a command and wait for output/status
	  process-wait         wait for process completion
  process-exit-code    read process exit code
  process-status       read implementation-specific status
  process-close        close process streams/resources

Process handle accessors:
  host-process-pid
  host-process-input-stream
  host-process-output-stream
  host-process-error-stream

Note:
  Prefer han.os for higher-level shell helpers. Use han.host when you need
  implementation-level process control.
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.host v~A~%" version))
    version))
