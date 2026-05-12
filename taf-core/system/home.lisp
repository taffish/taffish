(in-package :taf.core)

;;;; ============================================================
;;;; system / home.lisp
;;;; ============================================================

(defparameter *taffish-system-home-default*
  #P"/opt/taffish/")

(defparameter *taffish-system-bin-default*
  #P"/usr/local/bin/")

(defparameter *taffish-user-home-relative*
  ".local/share/taffish/")

(defparameter *taffish-home-required-dirs*
  '("apps"
    "index"
    "index/snapshots"
    "images"
    "images/sif"
    "images/metadata"
    "images/locks"
    "images/tmp"
    "bin"
    "cache"
    "cache/repos"
    "cache/downloads"
    "cache/build"
    "share"
    "share/completions"
    "share/completions/bash"
    "share/completions/zsh"
    "share/completions/fish"
    "share/vim"
    "share/vim/syntax"
    "share/vim/ftdetect"
    "logs"))

(defparameter *taffish-config-filename*
  "config.toml")

(defun %ensure-trailing-slash-string (string)
  (if (and (> (length string) 0)
           (char= #\/ (char string (1- (length string)))))
      string
      (format nil "~A/" string)))

(defun %directory-namestring (path)
  (han.path:->namestring (han.path:directory-pathname path)))

(defun %taffish-home-from-env (name)
  (let ((value (han.host:getenv name)))
    (when (and value (not (string= value "")))
      (han.path:directory-pathname (%ensure-trailing-slash-string value)))))

(defun %default-taffish-user-home ()
  (let ((home (han.os:home-directory)))
    (unless home
      (error "[system] can't detect user home directory. Set TAFFISH_USER_HOME."))
    (han.path:join-path home *taffish-user-home-relative*)))

(defun %taffish-user-home (&optional override)
  (han.path:directory-pathname
   (or override
       (%taffish-home-from-env "TAFFISH_USER_HOME")
       (%default-taffish-user-home))))

(defun %taffish-system-home (&optional override)
  (han.path:directory-pathname
   (or override
       (%taffish-home-from-env "TAFFISH_SYSTEM_HOME")
       *taffish-system-home-default*)))

(defun %taffish-system-bin-dir (&optional override)
  (han.path:directory-pathname
   (or override
       (%taffish-home-from-env "TAFFISH_SYSTEM_BIN_DIR")
       *taffish-system-bin-default*)))

(defun %normalize-taffish-scope (scope)
  (cond
    ((or (null scope) (eql scope :user)) :user)
    ((eql scope :system) :system)
    ((and (stringp scope) (string-equal scope "user")) :user)
    ((and (stringp scope) (string-equal scope "system")) :system)
    (t
     (error "[system] scope must be :user or :system, but got: ~S" scope))))

(defun %taffish-home (&key (scope :user) user-home system-home)
  (case (%normalize-taffish-scope scope)
    (:user (%taffish-user-home user-home))
    (:system (%taffish-system-home system-home))))

(defun %taffish-home-dir (home relative-dir)
  (han.path:directory-pathname
   (han.path:join-path home (%ensure-trailing-slash-string relative-dir))))

(defun %taffish-config-file (home)
  (han.path:join-path home *taffish-config-filename*))

(defun %taffish-user-config-file (&optional user-home)
  (%taffish-config-file (%taffish-user-home user-home)))

(defun %taffish-system-config-file (&optional system-home)
  (%taffish-config-file (%taffish-system-home system-home)))

(defun %taffish-command-bin-dir (scope home &optional system-bin-dir)
  (case (%normalize-taffish-scope scope)
    (:user (%taffish-home-dir home "bin"))
    (:system (%taffish-system-bin-dir system-bin-dir))))

(defun %taffish-home-required-dir-paths (home)
  (mapcar (lambda (relative-dir)
            (cons relative-dir (%taffish-home-dir home relative-dir)))
          *taffish-home-required-dirs*))

(defun %directory-exists-p (path)
  (not (null (han.path:directory-exists-p (han.path:directory-pathname path)))))

(defun %ensure-directory (path)
  (ensure-directories-exist (han.path:directory-pathname path)))

(defun %path-writable-p (path)
  (let ((shell (or (han.os:find-executable "sh")
                   (han.os:find-executable "bash"))))
    (when (and shell (%directory-exists-p path))
      (multiple-value-bind (out err code)
          (han.os:run-shell-command
           (format nil "test -w ~A"
                   (han.os:escape-sh-token (%directory-namestring path)))
           :lines nil
           :shell shell)
        (declare (ignore out err))
        (and (integerp code) (= code 0))))))

(defun %split-env-path (path)
  (let ((result nil)
        (start 0)
        (len (length path)))
    (labels ((emit (end)
               (push (subseq path start end) result)))
      (loop for index from 0 below len do
        (when (char= (char path index) #\:)
          (emit index)
          (setf start (1+ index))))
      (emit len))
    (nreverse result)))

(defun %path-dir-compare-string (path)
  (when (and path (not (string= path "")))
    (%directory-namestring (han.path:directory-pathname path))))

(defun %path-env-contains-dir-p (dir &optional (path-env (han.host:getenv "PATH")))
  (let ((target (%path-dir-compare-string (%directory-namestring dir))))
    (and target
         path-env
         (some (lambda (item)
                 (string= target
                          (or (%path-dir-compare-string item) "")))
               (%split-env-path path-env)))))

(defun %taffish-bin-dir-in-path-p (home)
  (%path-env-contains-dir-p (%taffish-home-dir home "bin")))

(defun %taffish-command-bin-dir-in-path-p (bin-dir)
  (%path-env-contains-dir-p bin-dir))

(defun %taffish-bin-path-export-command (bin-dir)
  (format nil "export PATH=\"~A:$PATH\""
          (string-right-trim '(#\/) (%directory-namestring bin-dir))))

(defun %current-uid ()
  (let ((id (han.os:find-executable "id")))
    (when id
      (multiple-value-bind (out err code)
          (han.os:run-program
           (list id "-u")
           :output :string
           :error-output :string
           :ignore-error-status t)
        (declare (ignore err))
        (when (and (integerp code) (= code 0))
          (ignore-errors
            (parse-integer
             (string-trim '(#\Space #\Tab #\Newline #\Return) out)
             :junk-allowed nil)))))))

(defun %root-user-p ()
  (eql (%current-uid) 0))
