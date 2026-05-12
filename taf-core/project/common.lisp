(in-package :taf.core)

;;;; ============================================================
;;;; project / common.lisp
;;;; ============================================================

;;;; defaults
(defparameter *default-github-host* "github.com")
(defparameter *default-github-owner* "taffish")
(defparameter *default-container-registry* "ghcr.io")
(defparameter *default-docker-base-image* "debian:12-slim")
(defparameter *default-index-repository* "taffish-index")
(defparameter *default-index-branch* "main")

;;;; name
(defun %ascii-alpha-char-p (char)
  (or (and (char>= char #\a) (char<= char #\z))
      (and (char>= char #\A) (char<= char #\Z))))

(defun %project-name-char-p (char)
  (or (%ascii-alpha-char-p char)
      (digit-char-p char)
      (member char '(#\- #\_) :test #'char=)))

(defun %bad-project-name-char (name)
  (when (and (stringp name)
             (not (string= name "")))
    (find-if-not #'%project-name-char-p name)))

(defun %valid-project-name-p (name)
  (and (stringp name)
       (> (length name) 0)
       (not (member (char name 0) '(#\- #\.) :test #'char=))
       (null (%bad-project-name-char name))))

;;;; version
(defun %valid-version-string-p (version)
  (and (stringp version)
       (> (length version) 0)
       (not (find #\Space version))
       (not (find #\Tab version))))

;;;; release
(defun %parse-positive-integer (string field-name)
  (let ((n (ignore-errors
            (parse-integer string :junk-allowed nil))))
    (unless (and n (> n 0))
      (error "[new] ~A must be a positive integer, but got: ~S"
             field-name string))
    n))

;;;; image
(defun %normalize-image-name (name)
  (string-downcase
   (substitute #\- #\_ name)))

;;;; repository
(defun %default-repository-url (name)
  (format nil "https://~A/~A/~A"
          *default-github-host*
          *default-github-owner*
          (%normalize-image-name name)))

(defun %default-container-image (name version release)
  (format nil "~A/~A/~A:~A-r~A"
          *default-container-registry*
          *default-github-owner*
          (%normalize-image-name name)
          version
          release))

(defun %default-base-container-image ()
  *default-docker-base-image*)

(defun %default-index-url ()
  (format nil "https://raw.githubusercontent.com/~A/~A/~A/index/index.json"
          *default-github-owner*
          *default-index-repository*
          *default-index-branch*))

(defun %repository-url-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (loop for i from 0 below (length prefix)
             always (char= (char prefix i) (char string i)))))

(defun %repository-path-p (path)
  (and (stringp path)
       (not (%blank-string-p path))
       (not (find #\Space path))
       (not (find #\Tab path))
       (let ((slash (position #\/ path)))
         (and slash
              (> slash 0)
              (< slash (1- (length path)))))))

(defun %github-repository-url-p (url)
  (labels ((after-prefix (prefix string)
             (subseq string (length prefix))))
    (and (stringp url)
         (or (and (%repository-url-prefix-p "https://github.com/" url)
                  (%repository-path-p
                   (after-prefix "https://github.com/" url)))
             (and (%repository-url-prefix-p "git@github.com:" url)
                  (%repository-path-p
                   (after-prefix "git@github.com:" url)))
             (and (%repository-url-prefix-p "ssh://git@github.com/" url)
                  (%repository-path-p
                   (after-prefix "ssh://git@github.com/" url)))))))

(defun %repository-url-p (url)
  (labels ((after-prefix (prefix string)
             (subseq string (length prefix)))
           (scheme-repository-p (prefix)
             (and (%repository-url-prefix-p prefix url)
                  (%repository-path-p (after-prefix prefix url)))))
    (and (stringp url)
         (not (%blank-string-p url))
         (not (find #\Space url))
         (not (find #\Tab url))
         (or (%github-repository-url-p url)
             (scheme-repository-p "https://")
             (scheme-repository-p "http://")
             (scheme-repository-p "ssh://")
             (let ((colon (and (%repository-url-prefix-p "git@" url)
                               (position #\: url))))
               (and colon
                    (> colon (length "git@"))
                    (%repository-path-p (subseq url (1+ colon)))))))))

(defun %ensure-repository-url (url field-name)
  (unless (%repository-url-p url)
    (error "~A must be a repository URL, but got: ~S"
           field-name url))
  url)

(defun %ensure-github-repository-url (url field-name)
  (unless (%github-repository-url-p url)
    (error "~A must be a GitHub repository URL, but got: ~S"
           field-name url))
  url)

;;;; kind: tool or flow
(defun %tool-or-flow (tool-p flow-p)
  (cond ((and tool-p flow-p)
         (error "[new] taf-app can't be tool and flow, must be one of them."))
        (tool-p :tool)
        (flow-p :flow)
        (t :flow)))

;;;; os
(defun %make-dir (path)
  (ensure-directories-exist (han.path:directory-pathname path)))

(defun %write-string-to-file (filespec string)
  (with-open-file (out filespec :direction :output
                                :if-exists :error
                                :if-does-not-exist :create)
    (format out "~A" string)))

(defun %project-file-path (root relative-path)
  (han.path:join-path root relative-path))

(defun %project-file-exists-p (path)
  (not (null (han.path:file-exists-p path))))

(defun %project-dir-exists-p (path)
  (not (null (han.path:directory-exists-p (han.path:directory-pathname path)))))

(defun %parent-directory (dir)
  (let* ((p (han.path:directory-pathname dir))
         (directory (pathname-directory p)))
    (when (and (consp directory)
               (cdr directory))
      (make-pathname :host (pathname-host p)
                     :device (pathname-device p)
                     :directory (butlast directory)
                     :name nil
                     :type nil
                     :version nil
                     :defaults p))))

;;;; %find-project-root
(defun %find-project-root (&optional (start-dir (han.os:current-directory)))
  (unless start-dir
    (error "[project] can't get current directory."))
  (labels ((scan (dir)
             (let ((toml (han.path:join-path dir "taffish.toml")))
               (cond
                 ((%project-file-exists-p toml)
                  (han.path:directory-pathname dir))
                 ((%parent-directory dir)
                  (scan (%parent-directory dir)))
                 (t
                  (error "[project] can't find taffish.toml from current directory upward."))))))
    (scan (han.path:directory-pathname
           (han.path:absolute-pathname start-dir)))))
