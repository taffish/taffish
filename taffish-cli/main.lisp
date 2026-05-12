(in-package :taffish.cli)

;;;; ============================================================
;;;; main.lisp
;;;; ============================================================

(defun %clean-string (string &key (trim-fun #'string-trim))
  (funcall trim-fun '(#\Space #\Tab) string))

(defun %strip-trailing-slash (string)
  (if (and (stringp string)
           (> (length string) 1)
           (char= #\/ (char string (1- (length string)))))
      (subseq string 0 (1- (length string)))
      string))

(defun %get-loaddir (load-path)
  (if (and load-path (or (stringp load-path)
                         (pathnamep load-path)))
      (%strip-trailing-slash
       (han.path:->namestring
        (han.path:absolute-pathname
         (han.path:parent-directory-pathname load-path))))
      (error "LOAD-FILE expect PATH or STRING, but got: [~S] ~S"
             (type-of load-path) load-path)))

(defun %parse-positive-integer (string)
  (when (and (stringp string)
             (not (string= "" (string-trim '(#\Space #\Tab #\Newline) string))))
    (let ((n (ignore-errors
              (parse-integer string :junk-allowed t))))
      (when (and n (> n 0))
        n))))

(defun %first-line (lines)
  (and (listp lines)
       (car lines)))

(defun %existing-regular-file-p (path)
  (not (null (ignore-errors (han.path:file-exists-p path)))))

(defun %try-get-cpus-by-command (command)
  (multiple-value-bind (out err exit-code)
      (han.os:run-shell-command command :wait t :lines t)
    (declare (ignore err))
    (when (and (integerp exit-code)
               (= exit-code 0))
      (%parse-positive-integer (%first-line out)))))

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
          (error "TAFFISH_CONTAINER_BACKEND must be apptainer, podman or docker, but got: ~S"
                 backend)))))
    (t
     (error "TAFFISH_CONTAINER_BACKEND must be a string or keyword, but got: ~S"
            (type-of backend)))))

(defun %make-container-config (&optional container-backend)
  (let ((config (list (cons :available-backends (%get-available-backends))))
        (force-backend (%normalize-container-backend container-backend)))
    (when force-backend
      (push (cons :force-backend force-backend) config))
    (nreverse config)))

(defun %fallback-homedir (user)
  (cond
    ((or (null user) (string= user ""))
     nil)
    ((string= user "root")
     "/root")
    (t
     (format nil "/home/~A" user))))

(defun %make-core-context (cmd input-source argv)
  (let* ((user (han.os:current-user))
         (home (or (han.os:home-directory)
                   (han.host:getenv "HOME")
                   (%fallback-homedir user))))
    (list (cons :user    user)
          (cons :homedir (and home (%strip-trailing-slash home)))
          (cons :workdir (%strip-trailing-slash (han.os:current-directory)))
          (cons :loaddir (case (car input-source)
                           (:file  (%get-loaddir (cdr input-source)))
                           (:stdin nil)))
          (cons :argv argv)
          (cons :cmd  cmd)
          (cons :cpus (%get-cpus))
          (cons :container
                (%make-container-config
                 (han.host:getenv "TAFFISH_CONTAINER_BACKEND"))))))

;; -> (values <input-source: (:stdin)/(:file . <file>)>
;;            <core-args>
;;            <core-context>)
(defun %parse-raw-args (raw-argv)
  (if raw-argv
      (let ((cmd (car raw-argv))
            (first (car (cdr raw-argv))))
        (cond
          ;; taffish
          ((null first)
           (let ((input-source '(:stdin)))
             (values input-source nil
                     (%make-core-context cmd input-source nil))))
          ;; taffish -h/--help ...
          ((let ((clean-first (%clean-string first)))
             (or (string= clean-first "-h")
                 (string= clean-first "--help")))
           (values :help nil nil))
          ;; taffish -v/--version ...
          ((let ((clean-first (%clean-string first)))
             (or (string= clean-first "-v")
                 (string= clean-first "--version")))
           (values :version nil nil))
          ;; taffish -- ...
          ((string= (%clean-string first) "--")
           (let ((input-source '(:stdin))
                 (core-args (cddr raw-argv)))
             (values input-source core-args
                     (%make-core-context cmd input-source core-args))))
          ((%existing-regular-file-p first)
           (let* ((load-path (han.path:->namestring (han.path:file-exists-p first)))
                  (input-source (cons :file load-path))
                  (core-args (cddr raw-argv)))
             (values input-source core-args
                     (%make-core-context cmd input-source core-args))))
          (t
           (let ((input-source '(:stdin))
                 (core-args (cdr raw-argv)))
             (values input-source core-args
                     (%make-core-context cmd input-source core-args))))))
      (error "Command missing!")))

;;;; -----------------------------------------------------------
;;;; main
;;;; -----------------------------------------------------------

(defun %print-caret-line (column)
  (when (and (integerp column)
             (> column 0))
    (format *error-output* "~A^~%"
            (make-string (+ column 3) :initial-element #\Space))))

(defun %print-taffish-error (condition)
  (let ((line (taffish.core:taffish-error-line condition))
        (column (taffish.core:taffish-error-column condition))
        (source-string (taffish.core:taffish-error-source-string condition))
        (message (taffish.core:taffish-error-message condition)))
    (format *error-output* "[TAFFISH-ERROR] ~A~%" message)
    (when line
      (format *error-output* "  --> line ~A" line)
      (when column
        (format *error-output* ", column ~A" column))
      (format *error-output* "~%"))
    (when source-string
      (format *error-output* "    ~A~%" source-string)
      (%print-caret-line column))))

(defun %print-general-error (condition)
  (format *error-output* "[TAFFISH-ERROR] ~A~%" condition))

(defun main (&optional (raw-argv (han.host:argv t)))
  (handler-case
      (progn
        (multiple-value-bind (input-source core-args core-context)
            (%parse-raw-args raw-argv)
          (case input-source
            (:help
             (run-taffish-help))
            (:version
             (run-taffish-version))
            (t
             (run-taffish-cli input-source core-args core-context))))
        (han.host:quit 0))
    (taffish.core:taffish-error (c)
      (%print-taffish-error c)
      (han.host:quit 1))
    (error (c)
      (%print-general-error c)
      (han.host:quit 1))))
