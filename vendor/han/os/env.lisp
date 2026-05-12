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
  (or (han.host:getenv "USER")
      (han.host:getenv "LOGNAME")
      default))

(defun current-directory ()
  "Return the current user's work directory as a string, or NIL if unavailable."
  (han.host:cwd))

(defun %directory-namestring-if-exists (path)
  (when (and path
             (or (stringp path) (pathnamep path)))
    (let ((directory (han.host:directory-exists-p path)))
      (when directory
        (namestring directory)))))

(defun home-directory ()
  "Return the current user's home directory as a string, or NIL if unavailable."
  (or (%directory-namestring-if-exists (han.host:getenv "HOME"))
      (%directory-namestring-if-exists (ignore-errors (user-homedir-pathname)))))

(defun %split-string (string separator)
  "Split STRING by character SEPARATOR and return a list of substrings."
  (let ((result '())
        (start 0)
        (len (length string)))
    (labels ((emit (end)
               (push (subseq string start end) result)))
      (loop for i from 0 below len do
        (if (char= (char string i) separator)
            (progn
              (emit i)
              (setf start (1+ i)))))
      (emit len))
    (nreverse result)))

(defparameter *default-executable-search-paths*
  '("/usr/local/bin" "/usr/bin" "/bin" "/usr/sbin" "/sbin"
    "/opt/homebrew/bin" "/opt/local/bin")
  "Fallback executable search paths used when PATH is unavailable or incomplete.")

(defun %path-search-directories ()
  (let ((path (han.host:getenv "PATH")))
    (append
     (when path
       (%split-string path #\:))
     *default-executable-search-paths*)))

(defun find-executable (program)
  "Search PROGRAM in PATH and return the first matching full path as a namestring.
Return NIL if not found.

Note:
- This function currently checks only file existence.
- It does not yet verify executable permission bits."
  (when (and program
             (stringp program)
             (> (length program) 0))
    ;; If PROGRAM already looks like a path, try it directly.
    (when (or (find #\/ program)
              (find #\\ program))
      (let ((p (han.host:file-exists-p program)))
        (when p
          (return-from find-executable (namestring p)))))
    ;; Otherwise search PATH, then a conservative Unix fallback path. LispWorks
    ;; launched from a GUI/IDE may not inherit a useful PATH.
    (let ((found-list nil))
      (dolist (dir-path (%path-search-directories))
        (let ((dir (han.host:directory-exists-p
                    (if (string= dir-path "") "." dir-path))))
          (when dir
            (let* ((candidate (merge-pathnames program dir))
                   (found (han.host:file-exists-p candidate)))
              (when found
                (pushnew (namestring found) found-list
                         :test #'string=))))))
      (when found-list
        (apply #'values (nreverse found-list))))))
