(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / compiler.lisp
;;;; ============================================================

(defparameter *mcp-max-taf-source-bytes* 1048576)

(defun %ensure-taf-source-size (source)
  (when (> (length source) *mcp-max-taf-source-bytes*)
    (error "TAF source is too large for MCP compiler tools: ~A bytes, max ~A bytes."
           (length source)
           *mcp-max-taf-source-bytes*))
  source)

(defun %required-json-string (arguments key)
  (multiple-value-bind (value present-p)
      (%json-get arguments key)
    (unless present-p
      (error "~A is required." key))
    (cond
      ((stringp value) value)
      ((or (null value) (eq value :null))
       (error "~A must be a string." key))
      (t
       (princ-to-string value)))))

(defun %compiler-string-prefix-p (prefix string)
  (and (stringp prefix)
       (stringp string)
       (<= (length prefix) (length string))
       (loop for i from 0 below (length prefix)
             always (char-equal (char prefix i) (char string i)))))

(defun %string-suffix-p (suffix string)
  (and (stringp suffix)
       (stringp string)
       (<= (length suffix) (length string))
       (let ((offset (- (length string) (length suffix))))
         (loop for i from 0 below (length suffix)
               always (char-equal (char suffix i)
                                  (char string (+ offset i)))))))

(defun %substring-present-p (needle string)
  (and (stringp needle)
       (stringp string)
       (not (null (search needle string :test #'char-equal)))))

(defun %normalize-compiler-backend (backend)
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
          (error "containerBackend or TAFFISH_CONTAINER_BACKEND must be apptainer, podman, or docker, got: ~S"
                 backend)))))
    (t
     (error "containerBackend or TAFFISH_CONTAINER_BACKEND must be apptainer, podman, or docker, got: ~S"
            backend))))

(defun %resolve-compiler-backend (explicit-backend)
  (%normalize-compiler-backend
   (or explicit-backend
       (han.host:getenv "TAFFISH_CONTAINER_BACKEND"))))

(defun %container-env-args (name)
  (let ((value (han.host:getenv name)))
    (when (and (stringp value)
               (not (string= "" (string-trim '(#\Space #\Tab #\Newline #\Return)
                                             value))))
      value)))

(defun %add-container-env-run-args (container-config)
  (let ((docker-run-args (%container-env-args "TAFFISH_DOCKER_RUN_ARGS"))
        (podman-run-args (%container-env-args "TAFFISH_PODMAN_RUN_ARGS"))
        (apptainer-run-args (%container-env-args "TAFFISH_APPTAINER_RUN_ARGS")))
    (when docker-run-args
      (push (cons :docker-env-run-args docker-run-args) container-config))
    (when podman-run-args
      (push (cons :podman-env-run-args podman-run-args) container-config))
    (when apptainer-run-args
      (push (cons :apptainer-env-exec-args apptainer-run-args) container-config))
    container-config))

(defun %mcp-available-backends ()
  (let ((out nil))
    (when (han.os:find-executable "apptainer")
      (push :apptainer out))
    (when (han.os:find-executable "podman")
      (push :podman out))
    (when (han.os:find-executable "docker")
      (push :docker out))
    (nreverse out)))

(defun %compiler-input-args (arguments)
  (or (%json-string-array-or-single arguments "args")
      '("taffish")))

(defun %fallback-homedir (user)
  (cond
    ((or (null user) (string= user "")) nil)
    ((string= user "root") "/root")
    (t (format nil "/home/~A" user))))

(defun %strip-trailing-slash (string)
  (if (and (stringp string)
           (> (length string) 1)
           (char= #\/ (char string (1- (length string)))))
      (subseq string 0 (1- (length string)))
      string))

(defun %compiler-load-dir (source-path)
  (if source-path
      (%strip-trailing-slash
       (han.path:->namestring
        (han.path:parent-directory-pathname
         (han.path:absolute-pathname source-path))))
      (%strip-trailing-slash
       (han.path:->namestring
        (han.path:directory-pathname
         (han.path:absolute-pathname (han.os:current-directory)))))))

(defun %compiler-work-dir ()
  (%strip-trailing-slash
   (han.path:->namestring
    (han.path:directory-pathname
     (han.path:absolute-pathname (han.os:current-directory))))))

(defun %compiler-context (arguments args &optional source-path)
  (let* ((user (han.os:current-user))
         (home (or (han.os:home-directory)
                   (han.host:getenv "HOME")
                   (%fallback-homedir user)))
         (backend (%resolve-compiler-backend
                   (%json-string arguments "containerBackend")))
         (container-config
           (list (cons :available-backends (%mcp-available-backends)))))
    (when backend
      (push (cons :force-backend backend) container-config))
    (setf container-config (%add-container-env-run-args container-config))
    (list (cons :user user)
          (cons :homedir (and home (%strip-trailing-slash home)))
          (cons :workdir (%compiler-work-dir))
          (cons :loaddir (%compiler-load-dir source-path))
          (cons :argv args)
          (cons :cmd (or (first args) "taffish"))
          (cons :container (nreverse container-config)))))

(defun %compiler-condition-plist (condition)
  (if (typep condition 'taffish.core:taffish-error)
      (list :message (taffish.core:taffish-error-message condition)
            :line (taffish.core:taffish-error-line condition)
            :column (taffish.core:taffish-error-column condition)
            :source-string (taffish.core:taffish-error-source-string condition))
      (list :message (format nil "~A" condition))))

(defun %line-kind-keyword (kind)
  (cond
    ((eq kind :empty) :empty)
    ((eq kind :comment) :comment)
    ((eq kind :tag) :tag)
    (t :code)))

(defun %line-kind-counts (lines)
  (let ((empty 0)
        (comment 0)
        (tag 0)
        (code 0))
    (dolist (line lines)
      (case (%line-kind-keyword (taffish.core:taf-line-kind line))
        (:empty (incf empty))
        (:comment (incf comment))
        (:tag (incf tag))
        (t (incf code))))
    (list :total (length lines)
          :empty empty
          :comment comment
          :tag tag
          :code code)))

(defun %line-token-text (line)
  (with-output-to-string (out)
    (dolist (token (taffish.core:taf-line-tokens line))
      (write-string (taffish.core:taf-token-value token) out))))

(defun %arg-spec-summary (arg-spec)
  (list :name (han.args:arg-spec-name arg-spec)
        :long-entry (han.args:arg-spec-long-entry arg-spec)
        :short-entry (han.args:arg-spec-short-entry arg-spec)
        :slot-entry (han.args:arg-spec-slot-entry arg-spec)
        :arity (han.args:arg-spec-arity arg-spec)
        :required (han.args:arg-spec-required arg-spec)
        :visibility (han.args:arg-spec-visibility arg-spec)
        :default (han.args:arg-spec-default arg-spec)))

(defun %program-args-summary (program)
  (let ((items nil))
    (maphash (lambda (name arg-spec)
               (declare (ignore name))
               (push (%arg-spec-summary arg-spec) items))
             (han.args:args-spec-args-table
              (taffish.core:taf-program-args-spec program)))
    (sort items #'string<
          :key (lambda (item) (or (getf item :name) "")))))

(defun %tag-backend (tag)
  (cond
    ((%compiler-string-prefix-p "docker:" tag) "docker")
    ((%compiler-string-prefix-p "podman:" tag) "podman")
    ((%compiler-string-prefix-p "apptainer:" tag) "apptainer")
    (t nil)))

(defun %block-summary (block)
  (let* ((head (car block))
         (tag (%line-token-text head))
         (backend (%tag-backend tag)))
    (list :tag tag
          :line (taffish.core:taf-line-line-number head)
          :backend backend
          :line-count (length block))))

(defun %program-blocks-summary (program)
  (mapcar #'%block-summary
          (taffish.core:taf-program-body program)))

(defun %container-blocks-summary (blocks)
  (remove-if-not (lambda (block) (getf block :backend))
                 blocks))

(defun %taf-app-blocks-summary (blocks)
  (remove-if-not (lambda (block)
                   (%compiler-string-prefix-p "taf-app:" (getf block :tag)))
                 blocks))

(defun %taf-call-lines (source)
  (let ((items nil)
        (line-number 1)
        (start 0)
        (len (length source)))
    (labels ((emit (end)
               (let ((line (subseq source start end)))
                 (when (%substring-present-p "[[taf:" line)
                   (push (list :line line-number
                               :text line)
                         items)))))
      (loop for i from 0 below len do
        (when (char= (char source i) #\Newline)
          (emit i)
          (incf line-number)
          (setf start (1+ i))))
      (emit len))
    (nreverse items)))

(defun %taffish-source-summary (source program)
  (let* ((lines (taffish.core:taf-program-lines program))
         (blocks (%program-blocks-summary program))
         (containers (%container-blocks-summary blocks))
         (taf-app-tags (%taf-app-blocks-summary blocks))
         (taf-calls (%taf-call-lines source)))
    (list :ok t
          :bytes (length source)
          :line-kinds (%line-kind-counts lines)
          :args (%program-args-summary program)
          :blocks blocks
          :containers containers
          :taf-app-tags taf-app-tags
          :taf-calls taf-calls
          :uses-taf-app (or taf-app-tags taf-calls))))

(defun %parse-taffish-source (source)
  (taffish.core:parse-taf source))

(defun %compile-taffish-source (source arguments &optional source-path)
  (let* ((program (%parse-taffish-source source))
         (args (%compiler-input-args arguments))
         (context (%compiler-context arguments args source-path))
         (result (taffish.core:bind-taf program args context))
         (shell (taffish.core:compile-taf result)))
    (values shell program)))

(defun %read-taf-source-file (path)
  (unless (%string-suffix-p ".taf" path)
    (error "path must point to a .taf file, got: ~S" path))
  (let ((file (han.path:file-exists-p path)))
    (unless file
      (error "TAF source file does not exist: ~A" path))
    (values (%ensure-taf-source-size
             (han.os:load-string file))
            file)))

(defun %call-taffish-validate-source (arguments)
  (let ((source (%ensure-taf-source-size
                 (%required-json-string arguments "source"))))
    (handler-case
        (multiple-value-bind (shell program)
            (%compile-taffish-source source arguments)
          (declare (ignore shell))
          (%tool-success
           "TAF source is valid."
           (list :ok t
                 :summary (%taffish-source-summary source program))))
      (error (c)
        (%tool-success
         "TAF source is invalid."
         (list :ok nil
               :error (%compiler-condition-plist c)))))))

(defun %call-taffish-compile-source (arguments)
  (let ((source (%ensure-taf-source-size
                 (%required-json-string arguments "source"))))
    (multiple-value-bind (shell program)
        (%compile-taffish-source source arguments)
      (%tool-success
       "Compiled TAF source to shell code."
       (list :ok t
             :shell shell
             :bytes (length shell)
             :summary (%taffish-source-summary source program))))))

(defun %call-taffish-summarize-source (arguments)
  (let* ((source (%ensure-taf-source-size
                  (%required-json-string arguments "source")))
         (program (%parse-taffish-source source)))
    (%tool-success
     "Summarized TAF source."
     (%taffish-source-summary source program))))

(defun %call-taffish-validate-file (arguments)
  (multiple-value-bind (source file)
      (%read-taf-source-file (%required-json-string arguments "path"))
    (handler-case
        (multiple-value-bind (shell program)
            (%compile-taffish-source source arguments file)
          (declare (ignore shell))
          (%tool-success
           "TAF file is valid."
           (list :ok t
                 :path (han.path:->namestring file)
                 :summary (%taffish-source-summary source program))))
      (error (c)
        (%tool-success
         "TAF file is invalid."
         (list :ok nil
               :path (han.path:->namestring file)
               :error (%compiler-condition-plist c)))))))

(defun %call-taffish-compile-file (arguments)
  (multiple-value-bind (source file)
      (%read-taf-source-file (%required-json-string arguments "path"))
    (multiple-value-bind (shell program)
        (%compile-taffish-source source arguments file)
      (%tool-success
       "Compiled TAF file to shell code."
       (list :ok t
             :path (han.path:->namestring file)
             :shell shell
             :bytes (length shell)
             :summary (%taffish-source-summary source program))))))

(defun %call-taffish-summarize-file (arguments)
  (multiple-value-bind (source file)
      (%read-taf-source-file (%required-json-string arguments "path"))
    (let ((program (%parse-taffish-source source)))
      (%tool-success
       "Summarized TAF file."
       (append (list :path (han.path:->namestring file))
               (%taffish-source-summary source program))))))
