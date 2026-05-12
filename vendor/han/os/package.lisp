(defpackage :han.os
  (:use :cl)
  (:shadow
   :load-string)
  (:export
   :help
   :version

   ;; IO
   :keep-read
   :keep-read-char
   :keep-read-line
   :load-lines
   :load-string

   ;; env
   :getenv-default
   :require-env
   :current-user
   :current-directory
	   :home-directory
	   :find-executable

	   ;;run-shell
	   :escape-sh-token
	   :run-program
	   :run-shell-command))

(in-package :han.os)

(defun %get-help-string ()
  "han.os v0.1.0

Purpose:
  Small operating-system utilities built on top of han.host.

Input helpers:
  keep-read
  keep-read-char
  keep-read-line
  load-lines
  load-string

Environment helpers:
  getenv-default
  require-env
  current-user
  current-directory
  home-directory
  find-executable

Shell helper:
	  escape-sh-token
	  run-program
	  run-shell-command

Common usage:
	  (han.os:getenv-default \"TAFFISH_USER_HOME\" default)
	  (han.os:require-env \"HOME\")
	  (han.os:find-executable \"git\")
	  (han.os:run-program '(\"git\" \"status\") :output :string)
	  (han.os:run-shell-command \"echo hello\")

Note:
  Use han.host for lower-level process handles. Use han.os when a compact
  OS-facing helper is enough.
")

(defun help (&optional (stream *standard-output*))
  (let ((text (%get-help-string)))
    (when stream
      (write-string text stream))
    text))

(defun version (&optional (stream *standard-output*))
  (let ((version "0.1.0"))
    (when stream
      (format stream "han.os v~A~%" version))
    version))
