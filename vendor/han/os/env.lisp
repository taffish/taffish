(in-package :han.os)

(defun getenv-default (name default)
  "Return the value of environment variable NAME,
or DEFAULT if NAME is not set."
  (or (han.host:getenv name)
      default))

(defun require-env (name)
  "Return the value of environment variable NAME.
Signal an error if NAME is not set."
  (or (han.host:getenv name)
      (error "Required environment variable ~A is not set." name)))

(defun current-user (&optional (default "World"))
  "Return the current user name, or DEFAULT if unavailable."
  (or (han.host:current-user) default))

(defun current-directory ()
  "Return the current user's work directory as a string, or NIL if unavailable."
  (han.host:cwd))

(defun home-directory ()
  "Return the current user's home directory as a string, or NIL if unavailable."
  (han.host:home-directory))

(defun find-executable (program)
  "Return each distinct match for PROGRAM as a namestring, in search order.
Return NIL if no existing file matches. Executable permission is not checked."
  (han.host:find-executable program))
