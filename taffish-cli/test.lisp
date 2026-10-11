(in-package :han.test)

(han.test:deftest test-taffish-cli-entry-startup-error-boundary ()
  (dolist (stage '(:io :language))
    (dolist (broken-stderr '(nil t))
      (let* ((symbols '(han.host:configure-runtime-io han.host:quit
                        taffish.i18n:call-with-resolved-language))
             (originals (mapcar #'symbol-function symbols))
             (exit-tag (gensym "CLI-EXIT"))
             (*standard-output* (make-string-output-stream))
             (*error-output* (if broken-stderr
                                 (make-string-input-stream "")
                                 (make-string-output-stream))))
        (unwind-protect
             (progn
               (setf (symbol-function 'han.host:configure-runtime-io)
                     (lambda ()
                       (when (eq stage :io) (error "startup test")))
                     (symbol-function 'taffish.i18n:call-with-resolved-language)
                     (lambda (function &rest options)
                       (declare (ignore function options))
                       (error "startup test"))
                     (symbol-function 'han.host:quit)
                     (lambda (&optional (code 0)) (throw exit-tag code)))
               (han.test:check-equal 1 (catch exit-tag (taffish.cli:main '("taffish" "--help"))))
               (han.test:check-equal "" (get-output-stream-string *standard-output*))
               (unless broken-stderr
                 (han.test:check-true
                  (search "[TAFFISH-ERROR] startup test"
                          (get-output-stream-string *error-output*)))))
          (loop for symbol in symbols for original in originals
                do (setf (symbol-function symbol) original)))))))


;;;; ============================================================
;;;; taffish.cli tests
;;;; ============================================================

(defun %taffish-cli-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %alist-ref (key alist)
  (cdr (assoc key alist :test #'eql)))

(defun %taffish-cli-string-contains-p (string substring)
  (and (stringp string)
       (stringp substring)
       (not (null (search substring string :test #'char=)))))

(defmacro %with-taffish-cli-env ((name value) &body body)
  (let ((old-getenv (gensym "OLD-GETENV"))
        (env-name (gensym "ENV-NAME"))
        (env-value (gensym "ENV-VALUE")))
    `(let ((,old-getenv (symbol-function 'han.host:getenv))
           (,env-name ,name)
           (,env-value ,value))
       (unwind-protect
            (progn
              (setf (symbol-function 'han.host:getenv)
                    (lambda (name)
                      (if (string= name ,env-name)
                          ,env-value
                          (funcall ,old-getenv name))))
              ,@body)
         (setf (symbol-function 'han.host:getenv) ,old-getenv)))))

(defun %make-temp-taf-file (&optional (content "RUN
<shell>
  echo hello"))
  (let* ((name (format nil "taffish-cli-test-~A.taf" (gensym)))
         (path (merge-pathnames name
                                (make-pathname
                                 :directory (pathname-directory
                                             (truename "."))))))
    (with-open-file (out path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (format out "~A" content))
    path))

(defun %delete-file-if-exists (path)
  (when (and path (probe-file path))
    (delete-file path)))

;;;; ------------------------------------------------------------
;;;; help / version / small helpers
;;;; ------------------------------------------------------------

(deftest test-taffish-cli-version-string-basic ()
  (check-equal (stringp taffish.cli:*taffish-version*) t)
  (check-equal (%taffish-cli-string-contains-p taffish.cli:*taffish-version* "taffish") t)
  (check-equal (%taffish-cli-string-contains-p taffish.cli:*taffish-version* "0.11.0") t)
  (check-equal taffish.cli:*taffish-version*
               "taffish     0.11.0"))

(deftest test-taffish-cli-help-string-basic ()
  (let ((help-string (taffish.cli::%get-taffish-help-string)))
    (check-equal (stringp help-string) t)
    (check-equal (%taffish-cli-string-contains-p help-string "Usage:") t)
    (check-equal (%taffish-cli-string-contains-p help-string "taffish [-h | --help]") t)
    (check-equal (%taffish-cli-string-contains-p help-string "taffish [-v | --version]") t)
    (check-equal (%taffish-cli-string-contains-p help-string "taffish <FILE.TAF> [ARGS...]") t)
    (check-equal (%taffish-cli-string-contains-p help-string "taffish -- [ARGS...]") t)
    (check-equal (%taffish-cli-string-contains-p help-string "TAFFISH_CONTAINER_BACKEND") t)))

(deftest test-taffish-cli-help-locales-preserve-options ()
  (let ((english (taffish.i18n:with-language ("en")
                   (taffish.cli::%get-taffish-help-string)))
        (chinese (taffish.i18n:with-language ("zh")
                   (taffish.cli::%get-taffish-help-string))))
    (check-true (search "Usage:" english :test #'char=))
    (check-true (search "用法：" chinese :test #'char=))
    (dolist (option '("-h" "--help" "-v" "--version" "--"))
      (check-true (search option english :test #'char=))
      (check-true (search option chinese :test #'char=)))))

(deftest test-taffish-cli-top-help-input-backends-and-contacts ()
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let ((help (taffish.cli::%get-taffish-help-string)))
        (dolist (text '("TAFFISH_CONTAINER_BACKEND" "apptainer" "podman" "docker"
                        "<container:...>" "TAFFISH_DOCKER_RUN_ARGS"
                        "TAFFISH_PODMAN_RUN_ARGS" "TAFFISH_APPTAINER_RUN_ARGS"
                        "taffish -- < example.taf > example.sh"
                        "TAFFISH_CONTAINER_BACKEND=podman taffish example.taf > example.sh"
                        "taf config language" "en" "auto"
                        "https://taffish.com" "https://taffish.github.io/"
                        "support@taffish.com"))
          (check-true (search text help)))
        (check-true (< (search "TAFFISH_APPTAINER_RUN_ARGS" help)
                       (search "taffish example.taf > example.sh" help)
                       (search "taf config language" help)
                       (search "https://taffish.com" help)))
        (dolist (pair '(("without executing" "不执行")
                        ("nonexistent filename" "文件名不存在")
                        ("A leading --" "开头的 --")
                        ("unset: choose an available backend" "未设置时自动选择可用后端")
                        ("not tags that explicitly name a backend" "不覆盖显式指定后端的标签")
                        ("host locale [default]" "跟随系统 [默认]")))
          (check-true (search (if (string= language "en") (first pair) (second pair))
                              help)))))))

(deftest test-taffish-cli-command-missing-is-localized ()
  (let ((english (taffish.i18n:with-language ("en")
                   (handler-case
                       (taffish.cli::%parse-raw-args nil)
                     (error (condition) (format nil "~A" condition)))))
        (chinese (taffish.i18n:with-language ("zh")
                   (handler-case
                       (taffish.cli::%parse-raw-args nil)
                     (error (condition) (format nil "~A" condition))))))
    (check-true (search "missing" english :test #'char-equal))
    (check-true (search "缺少" chinese :test #'char=))))

(deftest test-taffish-cli-strip-trailing-slash ()
  (check-equal (taffish.cli::%strip-trailing-slash "/tmp/") "/tmp")
  (check-equal (taffish.cli::%strip-trailing-slash "/") "/")
  (check-equal (taffish.cli::%strip-trailing-slash "/tmp") "/tmp")
  (check-equal (taffish.cli::%strip-trailing-slash "") ""))

(deftest test-taffish-cli-parse-positive-integer ()
  (check-equal (taffish.cli::%parse-positive-integer "8") 8)
  (check-equal (taffish.cli::%parse-positive-integer " 16 ") 16)
  (check-equal (taffish.cli::%parse-positive-integer "8cpu") 8)
  (check-equal (taffish.cli::%parse-positive-integer "0") nil)
  (check-equal (taffish.cli::%parse-positive-integer "-1") nil)
  (check-equal (taffish.cli::%parse-positive-integer "abc") nil)
  (check-equal (taffish.cli::%parse-positive-integer nil) nil))

(deftest test-taffish-cli-first-line ()
  (check-equal (taffish.cli::%first-line '("a" "b")) "a")
  (check-equal (taffish.cli::%first-line '()) nil)
  (check-equal (taffish.cli::%first-line nil) nil)
  (check-equal (taffish.cli::%first-line "abc") nil))

(deftest test-taffish-cli-get-cpus-basic ()
  (let ((cpus (taffish.cli::%get-cpus)))
    (check-equal (integerp cpus) t)
    (check-equal (> cpus 0) t)))

;;;; ------------------------------------------------------------
;;;; context
;;;; ------------------------------------------------------------

(deftest test-taffish-cli-make-core-context-stdin ()
  (let* ((context (taffish.cli::%make-core-context
                   "taffish"
                   '(:stdin)
                   '("--name" "alice"))))
    (check-equal (listp context) t)
    (check-equal (%alist-ref :cmd context) "taffish")
    (check-equal (%alist-ref :argv context) '("--name" "alice"))
    (check-equal (%alist-ref :loaddir context) nil)
    (check-equal (stringp (%alist-ref :user context)) t)
    (check-equal (or (null (%alist-ref :homedir context))
                     (stringp (%alist-ref :homedir context)))
                 t)
    (check-equal (stringp (%alist-ref :workdir context)) t)
    (check-equal (integerp (%alist-ref :cpus context)) t)
    (check-equal (> (%alist-ref :cpus context) 0) t)))

(deftest test-taffish-cli-make-core-context-file ()
  (let ((path nil))
    (unwind-protect
         (progn
           (setf path (%make-temp-taf-file))
           (let* ((input-source (cons :file (namestring path)))
                  (context (taffish.cli::%make-core-context
                            "taffish"
                            input-source
                            '("--x" "1"))))
             (check-equal (%alist-ref :cmd context) "taffish")
             (check-equal (%alist-ref :argv context) '("--x" "1"))
             (check-equal (stringp (%alist-ref :loaddir context)) t)
             (check-equal (%taffish-cli-string-contains-p (namestring path)
                                              (%alist-ref :loaddir context))
                          t)))
      (%delete-file-if-exists path))))

;;;; ------------------------------------------------------------
;;;; parse-raw-args
;;;; ------------------------------------------------------------

(deftest test-taffish-cli-parse-raw-args-command-missing-error ()
  (check-equal
   (%taffish-cli-signal-error-p
    (lambda ()
      (taffish.cli::%parse-raw-args nil)))
   t))

(deftest test-taffish-cli-parse-raw-args-no-extra-args ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish"))
    (check-equal input-source '(:stdin))
    (check-equal core-args nil)
    (check-equal (%alist-ref :cmd core-context) "taffish")
    (check-equal (%alist-ref :argv core-context) nil)
    (check-equal (%alist-ref :loaddir core-context) nil)))

(deftest test-taffish-cli-parse-raw-args-help-short ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "-h"))
    (check-equal input-source :help)
    (check-equal core-args nil)
    (check-equal core-context nil)))

(deftest test-taffish-cli-parse-raw-args-help-long ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "--help"))
    (check-equal input-source :help)
    (check-equal core-args nil)
    (check-equal core-context nil)))

(deftest test-taffish-cli-parse-raw-args-version-short ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "-v"))
    (check-equal input-source :version)
    (check-equal core-args nil)
    (check-equal core-context nil)))

(deftest test-taffish-cli-parse-raw-args-version-long ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "--version"))
    (check-equal input-source :version)
    (check-equal core-args nil)
    (check-equal core-context nil)))

(deftest test-taffish-cli-parse-raw-args-double-dash-empty ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "--"))
    (check-equal input-source '(:stdin))
    (check-equal core-args nil)
    (check-equal (%alist-ref :cmd core-context) "taffish")
    (check-equal (%alist-ref :argv core-context) nil)
    (check-equal (%alist-ref :loaddir core-context) nil)))

(deftest test-taffish-cli-parse-raw-args-double-dash-with-core-args ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args '("taffish" "--" "blastp" "-query" "a.fa"))
    (check-equal input-source '(:stdin))
    (check-equal core-args '("blastp" "-query" "a.fa"))
    (check-equal (%alist-ref :cmd core-context) "taffish")
    (check-equal (%alist-ref :argv core-context) '("blastp" "-query" "a.fa"))
    (check-equal (%alist-ref :loaddir core-context) nil)))

(deftest test-taffish-cli-parse-raw-args-nonexistent-file-falls-back-stdin ()
  (multiple-value-bind (input-source core-args core-context)
      (taffish.cli::%parse-raw-args
       '("taffish" "surely-not-existing-taffish-file-xyz" "--x" "1"))
    (check-equal input-source '(:stdin))
    (check-equal core-args '("surely-not-existing-taffish-file-xyz" "--x" "1"))
    (check-equal (%alist-ref :cmd core-context) "taffish")
    (check-equal (%alist-ref :argv core-context)
                 '("surely-not-existing-taffish-file-xyz" "--x" "1"))
    (check-equal (%alist-ref :loaddir core-context) nil)))

(deftest test-taffish-cli-parse-raw-args-file-mode ()
  (let ((path nil))
    (unwind-protect
         (progn
           (setf path (%make-temp-taf-file))
           (multiple-value-bind (input-source core-args core-context)
               (taffish.cli::%parse-raw-args
                (list "taffish" (namestring path) "--name" "alice"))
             (check-equal (car input-source) :file)
             (check-equal (stringp (cdr input-source)) t)
             (check-equal core-args '("--name" "alice"))
             (check-equal (%alist-ref :cmd core-context) "taffish")
             (check-equal (%alist-ref :argv core-context) '("--name" "alice"))
             (check-equal (stringp (%alist-ref :loaddir core-context)) t)))
      (%delete-file-if-exists path))))

(deftest test-taffish-cli-parse-raw-args-directory-not-file-mode ()
  (let* ((dir (namestring (truename ".")))
         (raw-argv (list "taffish" dir "--x" "1")))
    (multiple-value-bind (input-source core-args core-context)
        (taffish.cli::%parse-raw-args raw-argv)
      ;; 目录不能当作 taf 文件，应回退到 stdin 模式
      (check-equal input-source '(:stdin))
      (check-equal core-args (cdr raw-argv))
      (check-equal (%alist-ref :argv core-context) (cdr raw-argv)))))

(deftest test-taffish-cli-parse-raw-args-help-has-priority ()
  (let ((path nil))
    (unwind-protect
         (progn
           (setf path (%make-temp-taf-file))
           (multiple-value-bind (input-source core-args core-context)
               (taffish.cli::%parse-raw-args
                (list "taffish" "--help" (namestring path)))
             (check-equal input-source :help)
             (check-equal core-args nil)
             (check-equal core-context nil)))
      (%delete-file-if-exists path))))

(deftest test-taffish-cli-make-core-context-container-basic ()
  (let* ((context (taffish.cli::%make-core-context
                   "taffish"
                   '(:stdin)
                   '("--x" "1")))
         (container (cdr (assoc :container context :test #'eql)))
         (available (cdr (assoc :available-backends container :test #'eql))))
    (check-equal (listp container) t)
    (check-equal (listp available) t)
    (check-equal
     (every #'(lambda (x)
                (member x '(:apptainer :podman :docker) :test #'eql))
            available)
     t)))

(deftest test-taffish-cli-make-core-context-container-env-backend ()
  (%with-taffish-cli-env ("TAFFISH_CONTAINER_BACKEND" "podman")
    (let* ((context (taffish.cli::%make-core-context
                     "taffish"
                     '(:stdin)
                     nil))
           (container (cdr (assoc :container context :test #'eql))))
      (check-equal (cdr (assoc :force-backend container :test #'eql))
                   :podman))))

(deftest test-taffish-cli-make-core-context-container-env-run-args ()
  (%with-taffish-cli-env ("TAFFISH_DOCKER_RUN_ARGS" "--gpus all")
    (%with-taffish-cli-env ("TAFFISH_PODMAN_RUN_ARGS" "--device nvidia.com/gpu=all")
      (%with-taffish-cli-env ("TAFFISH_APPTAINER_RUN_ARGS" "--nv")
        (let* ((context (taffish.cli::%make-core-context
                         "taffish"
                         '(:stdin)
                         nil))
               (container (cdr (assoc :container context :test #'eql))))
          (check-equal (cdr (assoc :docker-env-run-args container :test #'eql))
                       "--gpus all")
          (check-equal (cdr (assoc :podman-env-run-args container :test #'eql))
                       "--device nvidia.com/gpu=all")
          (check-equal (cdr (assoc :apptainer-env-exec-args container :test #'eql))
                       "--nv"))))))

(deftest test-taffish-cli-normalize-container-backend-error ()
  (check-equal (taffish.cli::%normalize-container-backend nil) nil)
  (check-equal (taffish.cli::%normalize-container-backend "") nil)
  (check-equal (taffish.cli::%normalize-container-backend " docker ")
               :docker)
  (check-equal
   (%taffish-cli-signal-error-p
    (lambda ()
      (taffish.cli::%normalize-container-backend "bad-backend")))
   t))
