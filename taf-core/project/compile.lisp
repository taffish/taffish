(in-package :taf.core)

;;;; ============================================================
;;;; project / compile.lisp
;;;; ============================================================

(defun %strip-trailing-slash (string)
  (if (and (stringp string)
           (> (length string) 1)
           (char= #\/ (char string (1- (length string)))))
      (subseq string 0 (1- (length string)))
      string))

(defun %fallback-homedir (user)
  (cond
    ((or (null user) (string= user ""))
     nil)
    ((string= user "root")
     "/root")
    (t
     (format nil "/home/~A" user))))

(defun %parse-positive-integer-or-nil (string)
  (when (and (stringp string)
             (not (string= "" (string-trim '(#\Space #\Tab #\Newline)
                                           string))))
    (let ((n (ignore-errors
              (parse-integer string :junk-allowed t))))
      (when (and n (> n 0))
        n))))

(defun %first-line (lines)
  (and (listp lines)
       (car lines)))

(defun %try-get-cpus-by-command (command)
  (multiple-value-bind (out err exit-code)
      (han.os:run-shell-command command :wait t :lines t)
    (declare (ignore err))
    (when (and (integerp exit-code)
               (= exit-code 0))
      (%parse-positive-integer-or-nil (%first-line out)))))

(defun %get-cpus ()
  (or (%try-get-cpus-by-command "getconf _NPROCESSORS_ONLN")
      (%try-get-cpus-by-command "nproc")
      (%try-get-cpus-by-command "sysctl -n hw.ncpu")
      1))

(defun %get-available-backends ()
  (let ((out nil))
    (when (han.os:find-executable "apptainer")
      (push :apptainer out))
    (when (han.os:find-executable "podman")
      (push :podman out))
    (when (han.os:find-executable "docker")
      (push :docker out))
    (nreverse out)))

(defun %normalize-container-backend (backend)
  (cond
    ((null backend) nil)
    ((member backend '(:apptainer :podman :docker) :test #'eql)
     backend)
    ((stringp backend)
     (let ((clean-backend
             (string-trim '(#\Space #\Tab #\Newline #\Return) backend)))
       (cond
         ((string= clean-backend "") nil)
         ((string-equal clean-backend "apptainer") :apptainer)
         ((string-equal clean-backend "podman") :podman)
         ((string-equal clean-backend "docker") :docker)
         (t
          (error "[compile] container backend must be apptainer, podman or docker, but got: ~S"
                 backend)))))
    (t
     (error "[compile] container backend must be a string or keyword, but got: ~S"
            (type-of backend)))))

(defun %resolve-container-backend (explicit-backend)
  (%normalize-container-backend
   (or explicit-backend
       (han.host:getenv "TAFFISH_CONTAINER_BACKEND"))))

(defun %parse-project-compile-options (options)
  (unless (evenp (length options))
    (error "[compile] malformed keyword options: ~S" options))
  (loop for key in options by #'cddr do
    (unless (member key '(:container-backend) :test #'eql)
      (error "[compile] unknown option: ~S" key)))
  (list :container-backend (getf options :container-backend)))

(defun %absolute-directory-namestring (path)
  (%strip-trailing-slash
   (han.path:->namestring
    (han.path:directory-pathname
     (han.path:absolute-pathname path)))))

(defun %load-directory-namestring (file)
  (%strip-trailing-slash
   (han.path:->namestring
    (han.path:parent-directory-pathname
     (han.path:absolute-pathname file)))))

(defun %make-project-core-context
    (command-name main-file args workdir &key container-backend)
  (let* ((user (han.os:current-user))
         (home (or (han.os:home-directory)
                   (han.host:getenv "HOME")
                   (%fallback-homedir user)))
         (force-backend (%resolve-container-backend container-backend))
         (container-config
           (list (cons :available-backends (%get-available-backends)))))
    (when force-backend
      (push (cons :force-backend force-backend) container-config))
    (list (cons :user user)
          (cons :homedir (and home (%strip-trailing-slash home)))
          (cons :workdir (%absolute-directory-namestring workdir))
          (cons :loaddir (%load-directory-namestring main-file))
          (cons :argv args)
          (cons :cmd command-name)
          (cons :cpus (%get-cpus))
          (cons :container (nreverse container-config)))))

(defun project-compile (&optional (args nil)
                          (start-dir (han.os:current-directory))
                        &rest options)
  (unless (listp args)
    (error "[compile] ARGS must be a list, but got: ~S" (type-of args)))
  (let* ((parsed-options (%parse-project-compile-options options))
         (container-backend (getf parsed-options :container-backend))
         (project (project-check start-dir nil))
         (main-file (getf project :main-file))
         (command-name (getf project :command-name))
         (taf-code (han.os:load-string main-file))
         (context (%make-project-core-context
                   command-name main-file args start-dir
                   :container-backend container-backend)))
    (taffish.core:taffish-to-shell taf-code args context)))
