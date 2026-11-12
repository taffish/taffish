(in-package :han.test)

(han.test:deftest test-taf-cli-entry-startup-error-boundary ()
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
               (han.test:check-equal 1 (catch exit-tag (taf.cli:main '("--help"))))
               (han.test:check-equal "" (get-output-stream-string *standard-output*))
               (unless broken-stderr
                 (han.test:check-true
                  (search "[TAF-ERROR] startup test"
                          (get-output-stream-string *error-output*)))))
          (loop for symbol in symbols for original in originals
                do (setf (symbol-function symbol) original)))))))
(han.test:deftest test-taf-cli-progress-stream-ownership-at-entry ()
  ;; Stop just before command dispatch, with fd 2 on a terminal and the
  ;; caller's Lisp error stream already rebound. Never exit the test process.
  (let* ((symbols '(han.host:configure-runtime-io han.host:standard-error-terminal-p han.host:quit
                    taffish.i18n:call-with-resolved-language))
         (originals (mapcar #'symbol-function symbols))
         (tag (gensym "PROGRESS-STREAM")))
    (unwind-protect
         (progn
           (setf (symbol-function 'han.host:configure-runtime-io) (constantly t)
                 (symbol-function 'han.host:standard-error-terminal-p) (constantly t)
                 (symbol-function 'han.host:quit)
                 (lambda (&optional code) (declare (ignore code)) (throw tag :unexpected-exit))
                 (symbol-function 'taffish.i18n:call-with-resolved-language)
                 (lambda (function &rest options)
                   (declare (ignore function options))
                   (throw tag taf.core::*cli-terminal-error-output*)))
           (with-taf-system-temp-dir (dir)
             (let ((file (merge-pathnames "capture.log" dir)))
               (ensure-directories-exist file)
               (with-open-file (*error-output* file :direction :output :if-exists :error)
                 (check-equal nil (catch tag (taf.cli:main '("--version")))))))
           (let ((*error-output* (make-string-output-stream)))
             (check-equal nil (catch tag (taf.cli:main '("--version"))))
             (check-true (eq *error-output* (catch tag (taf.cli::%standalone-main '("--version")))))))
      (mapc (lambda (symbol function) (setf (symbol-function symbol) function))
            symbols originals))))

;;;; ============================================================
;;;; taf.cli tests
;;;; ============================================================

(defun %taf-cli-signal-error-p (thunk)
  (handler-case
      (progn
        (funcall thunk)
        nil)
    (error () t)))

(defun %taf-cli-string-contains-p (string substring)
  (and (stringp string)
       (stringp substring)
       (not (null (search substring string :test #'char=)))))

(defun %taf-cli-help-option-char-p (char)
  (or (and (char<= #\a char) (char<= char #\z))
      (and (char<= #\A char) (char<= char #\Z))
      (and (char<= #\0 char) (char<= char #\9))
      (char= char #\-)))

(defun %taf-cli-help-option-tokens (text)
  (let ((tokens nil)
        (length (length text)))
    (loop for index from 0 below length do
      (when (and (char= (char text index) #\-)
                 (or (zerop index)
                     (member (char text (1- index))
                             '(#\Space #\Tab #\Newline #\[ #\( #\| #\,)
                             :test #'char=)))
        (let ((end index))
          (loop while (and (< end length)
                           (%taf-cli-help-option-char-p (char text end)))
                do (incf end))
          (when (> end (1+ index))
            (push (subseq text index end) tokens)))))
    (sort (remove-duplicates tokens :test #'string=) #'string<)))

(defun %taf-cli-condition-string (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (error (condition) (format nil "~A" condition))))

(deftest test-taf-cli-version-string-basic ()
  (check-equal (stringp taf.cli:*taf-version*) t)
  (check-equal (%taf-cli-string-contains-p taf.cli:*taf-version* "taf") t)
  (check-equal (%taf-cli-string-contains-p taf.cli:*taf-version* "0.12.0") t)
  (check-equal taf.cli:*taf-version*
               "taf         0.12.0"))

(deftest test-taf-cli-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf help [COMMAND]") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf help install") t)
    (check-equal (%taf-cli-string-contains-p help-string "Project commands:") t)
    (check-equal (%taf-cli-string-contains-p help-string "Hub commands:") t)
    (check-equal (%taf-cli-string-contains-p help-string "System commands:") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "search      Search apps in the local index")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "index or a local project")
                 t)
    (check-false (%taf-cli-string-contains-p help-string
                                             "outdated [OPTIONS]"))
    (check-equal (%taf-cli-string-contains-p help-string
                                             "config language zh")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "host locale [default]")
                 t)))

(deftest test-taf-cli-top-help-navigation-and-contacts ()
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let ((help (taf.cli::%get-taf-help-string)))
        (dolist (command '("new" "check" "compile" "build" "run" "publish"
                           "update" "search" "info" "install" "outdated"
                           "upgrade" "prune" "uninstall" "list" "which"
                           "doctor" "config" "history"))
          (check-true (search (format nil "~%  ~A " command) help))
          (check-false (search "support@taffish.com"
                               (taf.cli::%get-taf-command-help-string command))))
        (dolist (text '("taf <COMMAND> [-h | --help]" "taf help [COMMAND]"
                        "taf update" "taf install fastqc" "taf help install"
                        "taf config language" "en" "auto"
                        "https://taffish.com" "https://taffish.github.io/"
                        "support@taffish.com"))
          (check-true (search text help)))
        (check-true (< (search "taf config language" help)
                       (search "https://taffish.com" help)))
        (check-true (search (if (string= language "en")
                               "read-only by default" "默认只读") help))
        (check-true (search (if (string= language "en")
                               "without upgrading apps" "不升级应用") help))
        (check-true (search (if (string= language "en")
                               "resume an interrupted publish" "继续中断的发布") help))))))

(deftest test-taf-cli-command-help-string-basic ()
  (check-equal
   (%taf-cli-string-contains-p
    (taf.cli::%get-taf-command-help-string "install")
    "taf install")
   t)
  (check-equal
   (%taf-cli-string-contains-p
    (taf.cli::%get-taf-command-help-string "upgrade")
    "taf upgrade")
   t)
  (check-equal
   (%taf-cli-string-contains-p
    (taf.cli::%get-taf-command-help-string "help")
    "taf help [COMMAND]")
   t)
  (check-equal
   (taf.cli::%get-taf-command-help-string "version")
   taf.cli:*taf-version*)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%get-taf-command-help-string "unknown-command")))
   t))

(deftest test-taf-cli-all-help-locales-preserve-option-contract ()
  (let ((commands '("new" "check" "compile" "build" "run" "publish"
                    "update" "search" "info" "install" "outdated"
                    "upgrade" "prune" "uninstall" "list" "which"
                    "doctor" "config" "history")))
    (dolist (command (cons nil commands))
      (let ((english
              (taffish.i18n:with-language ("en")
                (if command
                    (taf.cli::%get-taf-command-help-string command)
                    (taf.cli::%get-taf-help-string))))
            (chinese
              (taffish.i18n:with-language ("zh")
                (if command
                    (taf.cli::%get-taf-command-help-string command)
                    (taf.cli::%get-taf-help-string)))))
        (check-true (search "Usage:" english :test #'char=))
        (check-true (search "用法：" chinese :test #'char=))
        (check-equal (%taf-cli-help-option-tokens chinese)
                     (%taf-cli-help-option-tokens english))
        (unless command
          (check-false (search "[OPTIONS] <APP|COMMAND>" english
                               :test #'char=))
          (check-false (search "[OPTIONS] <APP|COMMAND>" chinese
                               :test #'char=))
          (check-true (search "  uninstall   Uninstall" english
                              :test #'char=))
          (check-true (search "  uninstall   卸载" chinese
                              :test #'char=)))
        (when command
          (check-true (search (format nil "taf ~A" command) english
                              :test #'char=))
          (check-true (search (format nil "taf ~A" command) chinese
                              :test #'char=)))))))

(deftest test-taf-cli-common-error-is-localized-with-stable-option ()
  (let ((english
          (taffish.i18n:with-language ("en")
            (%taf-cli-condition-string
             (lambda ()
               (taf.cli::%parse-taf-build-args '("--not-an-option"))))))
        (chinese
          (taffish.i18n:with-language ("zh")
            (%taf-cli-condition-string
             (lambda ()
               (taf.cli::%parse-taf-build-args '("--not-an-option")))))))
    (check-true (search "unknown option" english :test #'char=))
    (check-true (search "未知选项" chinese :test #'char=))
    (check-true (search "--not-an-option" english :test #'char=))
    (check-true (search "--not-an-option" chinese :test #'char=))))

(deftest test-taf-cli-strict-command-errors-are-localized ()
  ;; compile and run intentionally forward arbitrary arguments to the TAF
  ;; program, so they have no equivalent unknown-option parser failure.
  (dolist
      (case
       (list
        (list "new"
              (lambda () (taf.cli::run-taf-new nil))
              "taf new")
        (list "check"
              (lambda () (taf.cli::run-taf-check '("--i18n-invalid")))
              "taf check")
        (list "build"
              (lambda ()
                (taf.cli::%parse-taf-build-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "publish"
              (lambda ()
                (taf.cli::%parse-taf-publish-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "update"
              (lambda ()
                (taf.cli::%parse-taf-update-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "search"
              (lambda ()
                (taf.cli::%parse-taf-search-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "info"
              (lambda ()
                (taf.cli::%parse-taf-info-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "install"
              (lambda ()
                (taf.cli::%parse-taf-install-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "outdated"
              (lambda ()
                (taf.cli::%parse-taf-outdated-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "upgrade"
              (lambda ()
                (taf.cli::%parse-taf-upgrade-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "prune"
              (lambda ()
                (taf.cli::%parse-taf-prune-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "uninstall"
              (lambda ()
                (taf.cli::%parse-taf-uninstall-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "list"
              (lambda ()
                (taf.cli::%parse-taf-list-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "which"
              (lambda ()
                (taf.cli::%parse-taf-which-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "doctor"
              (lambda ()
                (taf.cli::%parse-taf-doctor-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "config"
              (lambda ()
                (taf.cli::%parse-taf-config-args '("--i18n-invalid")))
              "--i18n-invalid")
        (list "history"
              (lambda ()
                (taf.cli::%parse-taf-history-args '("--i18n-invalid")))
              "--i18n-invalid")))
    (destructuring-bind (command thunk stable-token) case
      (let ((english
              (taffish.i18n:with-language ("en")
                (%taf-cli-condition-string thunk)))
            (chinese
              (taffish.i18n:with-language ("zh")
                (%taf-cli-condition-string thunk))))
        (check-true english)
        (check-true chinese)
        (check-false (string= english chinese))
        (check-true (search stable-token english :test #'char=))
        (check-true (search stable-token chinese :test #'char=))
        (check-true (search (format nil "taf ~A" command) english
                            :test #'char=))
        (check-true (search (format nil "taf ~A" command) chinese
                            :test #'char=))))))

(deftest test-taf-cli-new-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-new-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf new [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf new <APP-NAME>") t)
    (check-equal (%taf-cli-string-contains-p help-string "--tool") t)
    (check-equal (%taf-cli-string-contains-p help-string "--license") t)
    (check-equal (%taf-cli-string-contains-p help-string "--repo") t)
    (check-equal (%taf-cli-string-contains-p help-string "--docker") t)
    (check-equal (%taf-cli-string-contains-p help-string "release.md") t)
    (check-equal (%taf-cli-string-contains-p help-string "--no-actions") t)))

(deftest test-taf-cli-parse-taf-new-args-basic ()
  (multiple-value-bind (name args)
      (taf.cli::%parse-taf-new-args '("demo" "--tool" "--docker"))
    (check-equal name "demo")
    (check-equal args '("--tool" "--docker"))))

(deftest test-taf-cli-run-taf-new-missing-name-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::run-taf-new nil)))
   t))

(deftest test-taf-cli-check-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-check-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf check [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "Details:") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf check") t)
    (check-equal (%taf-cli-string-contains-p help-string "taffish.toml") t)
    (check-equal (%taf-cli-string-contains-p help-string "main .taf") t)
    (check-equal (%taf-cli-string-contains-p help-string "smoke metadata") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "dependency/image consistency")
                 t)))

(deftest test-taf-cli-run-taf-check-extra-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::run-taf-check '("--unexpected"))))
   t))

(deftest test-taf-cli-compile-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-compile-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf compile [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "Details:") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf compile") t)
    (check-equal (%taf-cli-string-contains-p help-string "taffish.toml") t)
    (check-equal (%taf-cli-string-contains-p help-string "main .taf") t)))

(deftest test-taf-cli-parse-taf-compile-args-help ()
  (multiple-value-bind (mode args)
      (taf.cli::%parse-taf-compile-args '("-h"))
    (check-equal mode :help)
    (check-equal args nil)))

(deftest test-taf-cli-parse-taf-compile-args-separator ()
  (multiple-value-bind (mode args)
      (taf.cli::%parse-taf-compile-args '("--" "-h" "--name" "alice"))
    (check-equal mode :compile)
    (check-equal args '("-h" "--name" "alice"))))

(deftest test-taf-cli-build-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-build-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf build [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf build") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf build [-a | --all] [-b | --backend <docker|podman>]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-i, --image") t)
    (check-equal (%taf-cli-string-contains-p help-string "-a, --all") t)
    (check-equal (%taf-cli-string-contains-p help-string "-b, --backend") t)
    (check-equal (%taf-cli-string-contains-p help-string "--image") t)
    (check-equal (%taf-cli-string-contains-p help-string "--backend") t)))

(deftest test-taf-cli-parse-taf-build-args-default ()
  (multiple-value-bind (mode command-p image-p backend)
      (taf.cli::%parse-taf-build-args nil)
    (check-equal mode :build)
    (check-equal command-p t)
    (check-equal image-p nil)
    (check-equal backend nil)))

(deftest test-taf-cli-parse-taf-build-args-image ()
  (multiple-value-bind (mode command-p image-p backend)
      (taf.cli::%parse-taf-build-args '("-i"))
    (check-equal mode :build)
    (check-equal command-p nil)
    (check-equal image-p t)
    (check-equal backend nil)))

(deftest test-taf-cli-parse-taf-build-args-all-backend ()
  (multiple-value-bind (mode command-p image-p backend)
      (taf.cli::%parse-taf-build-args '("-a" "-b" "podman"))
    (check-equal mode :build)
    (check-equal command-p t)
    (check-equal image-p t)
    (check-equal backend "podman")))

(deftest test-taf-cli-parse-taf-build-args-help ()
  (multiple-value-bind (mode command-p image-p backend)
      (taf.cli::%parse-taf-build-args '("--help"))
    (check-equal mode :help)
    (check-equal command-p nil)
    (check-equal image-p nil)
    (check-equal backend nil)))

(deftest test-taf-cli-run-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-run-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf run [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf run [-b | --backend <docker|podman|apptainer>] -- [ARGS...]") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf run") t)
    (check-equal (%taf-cli-string-contains-p help-string "temporary shell") t)
    (check-equal (%taf-cli-string-contains-p help-string "-b, --backend") t)
    (check-equal (%taf-cli-string-contains-p help-string "--backend") t)
    (check-equal (%taf-cli-string-contains-p help-string "Options:") t)
    (check-equal (%taf-cli-string-contains-p help-string "STDOUT/STDERR") t)
    (check-equal (%taf-cli-string-contains-p help-string "pipe/file") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "TAFFISH_CONTAINER_BACKEND")
                 t)))

(deftest test-taf-cli-run-input-uses-host-terminal-state ()
  (let ((original (symbol-function 'han.host:standard-input-terminal-p)))
    (unwind-protect
         (progn
           (setf (symbol-function 'han.host:standard-input-terminal-p)
                 (lambda () t))
           (check-equal (taf.cli::%taf-run-input) nil)
           (setf (symbol-function 'han.host:standard-input-terminal-p)
                 (lambda () nil))
           (check-equal (taf.cli::%taf-run-input) t))
      (setf (symbol-function 'han.host:standard-input-terminal-p) original))))

(deftest test-taf-cli-parse-taf-run-args-default ()
  (multiple-value-bind (mode args)
      (taf.cli::%parse-taf-run-args nil)
    (check-equal mode :run)
    (check-equal args nil)))

(deftest test-taf-cli-parse-taf-run-args-help ()
  (multiple-value-bind (mode args)
      (taf.cli::%parse-taf-run-args '("--help"))
    (check-equal mode :help)
    (check-equal args nil)))

(deftest test-taf-cli-parse-taf-run-args-separator ()
  (multiple-value-bind (mode args backend)
      (taf.cli::%parse-taf-run-args '("--" "-h" "--name" "alice"))
    (check-equal mode :run)
    (check-equal backend nil)
    (check-equal args '("-h" "--name" "alice"))))

(deftest test-taf-cli-parse-taf-run-args-backend ()
  (multiple-value-bind (mode args backend)
      (taf.cli::%parse-taf-run-args
       '("-b" "docker" "--name" "alice"))
    (check-equal mode :run)
    (check-equal backend "docker")
    (check-equal args '("--name" "alice"))))

(deftest test-taf-cli-parse-taf-run-args-backend-separator ()
  (multiple-value-bind (mode args backend)
      (taf.cli::%parse-taf-run-args
       '("--backend" "podman" "--" "--backend" "app-value"))
    (check-equal mode :run)
    (check-equal backend "podman")
    (check-equal args '("--backend" "app-value"))))

(deftest test-taf-cli-publish-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-publish-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf publish [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-n, --dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "-y, --yes") t)
    (check-equal (%taf-cli-string-contains-p help-string "-b, --build") t)
    (check-equal (%taf-cli-string-contains-p help-string "-r, --release") t)
    (check-equal (%taf-cli-string-contains-p help-string "--dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "--yes") t)
    (check-equal (%taf-cli-string-contains-p help-string "--latest") t)
    (check-equal (%taf-cli-string-contains-p help-string "--pre") t)
    (check-equal (%taf-cli-string-contains-p help-string "--create-repo") t)
    (check-equal (%taf-cli-string-contains-p help-string "--public") t)
    (check-equal (%taf-cli-string-contains-p help-string "--private") t)
    (check-equal (%taf-cli-string-contains-p help-string "--no-lock-repo") t)
    (check-equal (%taf-cli-string-contains-p help-string "--prompt") t)
    (check-equal (%taf-cli-string-contains-p help-string "immutable releases") t)
    (check-equal (%taf-cli-string-contains-p help-string "v* tags") t)
    (check-equal (%taf-cli-string-contains-p help-string "release.md") t)
    (check-equal (%taf-cli-string-contains-p help-string "GitHub release") t)
    (check-equal (%taf-cli-string-contains-p help-string "v<version>-r<release>") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "rerun the same command")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "already created by")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "valid artifacts are not rewritten")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "skips rebuilding")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "successful no-op")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string "conflicting commits") t)
    (check-equal (%taf-cli-string-contains-p help-string "fail fast") t)
    (let ((chinese
            (taffish.i18n:with-language ("zh")
              (taf.cli::%get-taf-publish-help-string))))
      (check-equal (%taf-cli-string-contains-p chinese
                                               "重新运行完全相同的命令")
                   t)
      (check-equal (%taf-cli-string-contains-p chinese
                                               "已由 --create-repo 创建")
                   t)
      (check-equal (%taf-cli-string-contains-p chinese
                                               "不会重写文件")
                   t)
      (check-equal (%taf-cli-string-contains-p chinese
                                               "跳过重建")
                   t)
      (check-equal (%taf-cli-string-contains-p chinese
                                               "不会重复执行发布修改")
                   t))))

(deftest test-taf-cli-parse-taf-publish-args-default ()
  (multiple-value-bind
        (mode dry-run build-p channel prompt-p create-repo-p repo-visibility
         release-p lock-repo-p)
      (taf.cli::%parse-taf-publish-args nil)
    (check-equal mode :publish)
    (check-equal dry-run t)
    (check-equal build-p nil)
    (check-equal channel :latest)
    (check-equal prompt-p nil)
    (check-equal create-repo-p nil)
    (check-equal repo-visibility :public)
    (check-equal release-p nil)
    (check-equal lock-repo-p t)))

(deftest test-taf-cli-parse-taf-publish-args-yes-pre-build ()
  (multiple-value-bind
        (mode dry-run build-p channel prompt-p create-repo-p repo-visibility
         release-p lock-repo-p)
      (taf.cli::%parse-taf-publish-args
       '("-y" "--pre" "-b" "-r" "--prompt" "--create-repo" "--private"))
    (check-equal mode :publish)
    (check-equal dry-run nil)
    (check-equal build-p t)
    (check-equal channel :pre)
    (check-equal prompt-p t)
    (check-equal create-repo-p t)
    (check-equal repo-visibility :private)
    (check-equal release-p t)
    (check-equal lock-repo-p t)))

(deftest test-taf-cli-parse-taf-publish-args-no-lock-repo ()
  (multiple-value-bind
        (mode dry-run build-p channel prompt-p create-repo-p repo-visibility
         release-p lock-repo-p)
      (taf.cli::%parse-taf-publish-args
       '("--create-repo" "--no-lock-repo"))
    (check-equal mode :publish)
    (check-equal dry-run t)
    (check-equal build-p nil)
    (check-equal channel :latest)
    (check-equal prompt-p nil)
    (check-equal create-repo-p t)
    (check-equal repo-visibility :public)
    (check-equal release-p nil)
    (check-equal lock-repo-p nil)))

(deftest test-taf-cli-parse-taf-publish-args-help ()
  (multiple-value-bind (mode dry-run build-p channel)
      (taf.cli::%parse-taf-publish-args '("--help"))
    (check-equal mode :help)
    (check-equal dry-run nil)
    (check-equal build-p nil)
    (check-equal channel nil)))

(deftest test-taf-cli-parse-taf-publish-args-conflict-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-publish-args '("--yes" "--dry-run"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-publish-args '("--latest" "--pre"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-publish-args '("--public" "--private"))))
   t))

(deftest test-taf-cli-update-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-update-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf update [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--user") t)
    (check-equal (%taf-cli-string-contains-p help-string "--system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--url") t)
    (check-equal (%taf-cli-string-contains-p help-string "TAFFISH_INDEX_URL") t)
    (check-equal (%taf-cli-string-contains-p help-string "index/current.json") t)))

(deftest test-taf-cli-parse-taf-update-args-default ()
  (multiple-value-bind (mode scope index-url yes-p)
      (taf.cli::%parse-taf-update-args nil)
    (check-equal mode :update)
    (check-equal scope :user)
    (check-equal index-url nil)
    (check-equal yes-p nil)))

(deftest test-taf-cli-parse-taf-update-args-system-url-yes ()
  (multiple-value-bind (mode scope index-url yes-p)
      (taf.cli::%parse-taf-update-args
       '("-s" "--url" "file:///tmp/index.json" "-y"))
    (check-equal mode :update)
    (check-equal scope :system)
    (check-equal index-url "file:///tmp/index.json")
    (check-equal yes-p t)))

(deftest test-taf-cli-parse-taf-update-args-help ()
  (multiple-value-bind (mode scope index-url yes-p)
      (taf.cli::%parse-taf-update-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal index-url nil)
    (check-equal yes-p nil)))

(deftest test-taf-cli-parse-taf-update-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-update-args '("--user" "--system"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-update-args '("--url"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-update-args '("--bad"))))
   t))

(deftest test-taf-cli-search-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-search-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf search [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "<KEYWORD...>") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "-l, --limit") t)
    (check-equal (%taf-cli-string-contains-p help-string "--user") t)
    (check-equal (%taf-cli-string-contains-p help-string "--system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--limit") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf update") t)))

(deftest test-taf-cli-parse-taf-search-args-default ()
  (multiple-value-bind (mode scope query limit json-p)
      (taf.cli::%parse-taf-search-args '("bwa"))
    (check-equal mode :search)
    (check-equal scope :user)
    (check-equal query "bwa")
    (check-equal limit 20)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-search-args-system-json-limit-terms ()
  (multiple-value-bind (mode scope query limit json-p)
      (taf.cli::%parse-taf-search-args
       '("-s" "-j" "-l" "5" "hic" "flow"))
    (check-equal mode :search)
    (check-equal scope :system)
    (check-equal query "hic flow")
    (check-equal limit 5)
    (check-equal json-p t)))

(deftest test-taf-cli-parse-taf-search-args-help ()
  (multiple-value-bind (mode scope query limit json-p)
      (taf.cli::%parse-taf-search-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal query nil)
    (check-equal limit nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-search-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-search-args nil)))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-search-args '("--user" "--system" "bwa"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-search-args '("--limit" "0" "bwa"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-search-args '("--bad" "bwa"))))
   t))

(deftest test-taf-cli-info-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-info-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf info [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "<APP-NAME|TAF-COMMAND>") t)
    (check-equal (%taf-cli-string-contains-p help-string "VERSION-ID") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "all indexed versions") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf update") t)))

(deftest test-taf-cli-parse-taf-info-args-default ()
  (multiple-value-bind (mode scope query version-id json-p)
      (taf.cli::%parse-taf-info-args '("my-new-test"))
    (check-equal mode :info)
    (check-equal scope :user)
    (check-equal query "my-new-test")
    (check-equal version-id nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-info-args-system-json-version ()
  (multiple-value-bind (mode scope query version-id json-p targets)
      (taf.cli::%parse-taf-info-args
       '("-s" "-j" "taf-my-new-test" "v0.1.0-r1"))
    (check-equal mode :info)
    (check-equal scope :system)
    (check-equal query "taf-my-new-test")
    (check-equal version-id "v0.1.0-r1")
    (check-equal json-p t)
    (check-equal (length targets) 1)
    (check-equal (getf (first targets) :query) "taf-my-new-test")
    (check-equal (getf (first targets) :version-id) "v0.1.0-r1")))

(deftest test-taf-cli-parse-taf-info-args-batch ()
  (multiple-value-bind (mode scope query version-id json-p targets)
      (taf.cli::%parse-taf-info-args
       '("--json" "my-new-test" "taf-other-v0.2.0-r1"))
    (check-equal mode :info)
    (check-equal scope :user)
    (check-equal query "my-new-test")
    (check-equal version-id nil)
    (check-equal json-p t)
    (check-equal (length targets) 2)
    (check-equal (getf (first targets) :query) "my-new-test")
    (check-equal (getf (second targets) :query) "taf-other-v0.2.0-r1")))

(deftest test-taf-cli-parse-taf-info-args-help ()
  (multiple-value-bind (mode scope query version-id json-p)
      (taf.cli::%parse-taf-info-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-info-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-info-args nil)))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-info-args '("--user" "--system" "app"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-info-args '("app" "v1-r1" "extra"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-info-args '("--bad" "app"))))
   t))

(deftest test-taf-cli-install-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-install-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf install [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "Modes:") t)
    (check-equal (%taf-cli-string-contains-p help-string "Examples:") t)
    (check-equal (%taf-cli-string-contains-p help-string "indexed target") t)
    (check-equal (%taf-cli-string-contains-p help-string "local project") t)
    (check-equal (%taf-cli-string-contains-p help-string "<APP-NAME|TAF-COMMAND>") t)
    (check-equal (%taf-cli-string-contains-p help-string "VERSION-ID") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-n, --dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "-f, --force") t)
    (check-equal (%taf-cli-string-contains-p help-string "--from <PROJECT-DIR>") t)
    (check-equal (%taf-cli-string-contains-p help-string "--dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "--force") t)
    (check-equal (%taf-cli-string-contains-p help-string "--prompt") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "taf-my-tool-v0.1.0-r1")
                 t)
    (check-equal (%taf-cli-string-contains-p help-string "[local-project]") t)
    (check-equal (%taf-cli-string-contains-p help-string "searches upward") t)
    (check-equal (%taf-cli-string-contains-p help-string "exact command") t)))

(deftest test-taf-cli-parse-taf-install-args-default ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p)
      (taf.cli::%parse-taf-install-args '("install-demo"))
    (check-equal mode :install)
    (check-equal scope :user)
    (check-equal query "install-demo")
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)
    (check-equal prompt-p nil)))

(deftest test-taf-cli-parse-taf-install-args-artifact-command ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p)
      (taf.cli::%parse-taf-install-args
       '("taf-install-demo-v0.1.0-r1"))
    (check-equal mode :install)
    (check-equal scope :user)
    (check-equal query "taf-install-demo-v0.1.0-r1")
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)
    (check-equal prompt-p nil)))

(deftest test-taf-cli-parse-taf-install-args-system-force-version ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets)
      (taf.cli::%parse-taf-install-args
       '("-s" "-n" "-f" "--prompt"
         "taf-install-demo" "v0.1.0-r1"))
    (check-equal mode :install)
    (check-equal scope :system)
    (check-equal query "taf-install-demo")
    (check-equal version-id "v0.1.0-r1")
    (check-equal dry-run-p t)
    (check-equal force-p t)
    (check-equal prompt-p t)
    (check-equal (length targets) 1)
    (check-equal (getf (first targets) :query) "taf-install-demo")
    (check-equal (getf (first targets) :version-id) "v0.1.0-r1")))

(deftest test-taf-cli-parse-taf-install-args-batch ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets)
      (taf.cli::%parse-taf-install-args
       '("-n" "taf-install-a" "taf-install-b-v0.2.0-r1"))
    (check-equal mode :install)
    (check-equal scope :user)
    (check-equal query "taf-install-a")
    (check-equal version-id nil)
    (check-equal dry-run-p t)
    (check-equal force-p nil)
    (check-equal prompt-p nil)
    (check-equal (length targets) 2)
    (check-equal (getf (first targets) :query) "taf-install-a")
    (check-equal (getf (first targets) :version-id) nil)
    (check-equal (getf (second targets) :query) "taf-install-b-v0.2.0-r1")
    (check-equal (getf (second targets) :version-id) nil)))

(deftest test-taf-cli-parse-taf-install-args-from-project ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets from-dir)
      (taf.cli::%parse-taf-install-args
       '("-s" "-n" "-f" "--from" "/tmp/private-app"))
    (check-equal mode :install-from-project)
    (check-equal scope :system)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal dry-run-p t)
    (check-equal force-p t)
    (check-equal prompt-p nil)
    (check-equal targets nil)
    (check-equal from-dir "/tmp/private-app")))

(deftest test-taf-cli-parse-taf-install-args-all-tools-json ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets from-dir
         all-p kind yes-p json-p prune-old-p)
      (taf.cli::%parse-taf-install-args
       '("--all" "--tools" "--yes" "--json" "--prune-old"))
    (check-equal mode :install-all)
    (check-equal scope :user)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)
    (check-equal prompt-p nil)
    (check-equal targets nil)
    (check-equal from-dir nil)
    (check-equal all-p t)
    (check-equal kind :tool)
    (check-equal yes-p t)
    (check-equal json-p t)
    (check-equal prune-old-p t)))

(deftest test-taf-cli-parse-taf-install-args-help ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p)
      (taf.cli::%parse-taf-install-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)
    (check-equal prompt-p nil)))

(deftest test-taf-cli-parse-taf-install-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args nil)))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args
       '("--user" "--system" "install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args
       '("install-demo" "v0.1.0-r1" "extra"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args '("--bad" "install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args
       '("--from" "/tmp/private-app" "install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args '("--from"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args '("--all" "install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-install-args '("--all" "--dry-run" "--yes"))))
   t))

(deftest test-taf-cli-outdated-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-outdated-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf outdated") t)
    (check-equal (%taf-cli-string-contains-p help-string "[-a | --all]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-k, --kind") t)
    (check-equal (%taf-cli-string-contains-p help-string "--tools") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "no changes") t)
    (check-equal (%taf-cli-string-contains-p help-string "Examples:") t)))

(deftest test-taf-cli-parse-taf-outdated-args-targets ()
  (multiple-value-bind (mode scope kind json-p targets)
      (taf.cli::%parse-taf-outdated-args
       '("-s" "-j" "--kind" "flow" "taf-flow-a" "taf-flow-b"))
    (check-equal mode :outdated)
    (check-equal scope :system)
    (check-equal kind :flow)
    (check-equal json-p t)
    (check-equal (length targets) 2)
    (check-equal (getf (first targets) :query) "taf-flow-a")
    (check-equal (getf (second targets) :query) "taf-flow-b")))

(deftest test-taf-cli-upgrade-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-upgrade-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf upgrade") t)
    (check-equal (%taf-cli-string-contains-p help-string "[-a | --all]") t)
    (check-equal (%taf-cli-string-contains-p help-string "--prune-old") t)
    (check-equal (%taf-cli-string-contains-p help-string "--yes") t)
    (check-equal (%taf-cli-string-contains-p help-string "--prompt") t)
    (check-equal (%taf-cli-string-contains-p help-string "no changes") t)
    (check-equal (%taf-cli-string-contains-p help-string "Examples:") t)))

(deftest test-taf-cli-parse-taf-upgrade-args-default-all ()
  (multiple-value-bind
        (mode scope kind dry-run-p yes-p force-p prompt-p prune-old-p json-p targets)
      (taf.cli::%parse-taf-upgrade-args nil)
    (check-equal mode :upgrade)
    (check-equal scope :user)
    (check-equal kind :all)
    (check-equal dry-run-p nil)
    (check-equal yes-p nil)
    (check-equal force-p nil)
    (check-equal prompt-p nil)
    (check-equal prune-old-p nil)
    (check-equal json-p nil)
    (check-equal targets nil)))

(deftest test-taf-cli-parse-taf-upgrade-args-yes-kind-target ()
  (multiple-value-bind
        (mode scope kind dry-run-p yes-p force-p prompt-p prune-old-p json-p targets)
      (taf.cli::%parse-taf-upgrade-args
       '("-s" "--yes" "--flows" "--force" "--prompt" "--prune-old" "-j"
         "taf-flow-v1.0.0-r1"))
    (check-equal mode :upgrade)
    (check-equal scope :system)
    (check-equal kind :flow)
    (check-equal dry-run-p nil)
    (check-equal yes-p t)
    (check-equal force-p t)
    (check-equal prompt-p t)
    (check-equal prune-old-p t)
    (check-equal json-p t)
    (check-equal (length targets) 1)
    (check-equal (getf (first targets) :query) "taf-flow-v1.0.0-r1")))

(deftest test-taf-cli-prune-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-prune-help-string)))
    (check-true (search "index latest" help-string))
    (check-true (search "unknown-source" help-string))
    (check-equal (%taf-cli-string-contains-p help-string "taf prune") t)
    (check-equal (%taf-cli-string-contains-p help-string "[-a | --all]") t)
    (check-equal (%taf-cli-string-contains-p help-string "--yes") t)
    (check-equal (%taf-cli-string-contains-p help-string "--kind") t)
    (check-equal (%taf-cli-string-contains-p help-string "SIF files") t)
    (check-equal (%taf-cli-string-contains-p help-string "no changes") t)
    (check-equal (%taf-cli-string-contains-p help-string "Examples:") t)))

(deftest test-taf-cli-parse-taf-prune-args-targets ()
  (multiple-value-bind (mode scope kind dry-run-p yes-p json-p targets)
      (taf.cli::%parse-taf-prune-args
       '("-n" "--tools" "-j" "taf-tool-a" "taf-tool-b"))
    (check-equal mode :prune)
    (check-equal scope :user)
    (check-equal kind :tool)
    (check-equal dry-run-p t)
    (check-equal yes-p nil)
    (check-equal json-p t)
    (check-equal (length targets) 2)))

(deftest test-taf-cli-list-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-list-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf list [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-l, --local") t)
    (check-equal (%taf-cli-string-contains-p help-string "-o, --online") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "-n, --limit") t)
    (check-equal (%taf-cli-string-contains-p help-string "--local") t)
    (check-equal (%taf-cli-string-contains-p help-string "--online") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--limit") t)
    (check-equal (%taf-cli-string-contains-p help-string "install metadata") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf update") t)))

(deftest test-taf-cli-parse-taf-list-args-default ()
  (multiple-value-bind (mode scope list-mode limit json-p)
      (taf.cli::%parse-taf-list-args nil)
    (check-equal mode :list)
    (check-equal scope :user)
    (check-equal list-mode :local)
    (check-equal limit nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-list-args-online-system-json-limit ()
  (multiple-value-bind (mode scope list-mode limit json-p)
      (taf.cli::%parse-taf-list-args
       '("-o" "-s" "-j" "-n" "5"))
    (check-equal mode :list)
    (check-equal scope :system)
    (check-equal list-mode :online)
    (check-equal limit 5)
    (check-equal json-p t)))

(deftest test-taf-cli-parse-taf-list-args-help ()
  (multiple-value-bind (mode scope list-mode limit json-p)
      (taf.cli::%parse-taf-list-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal list-mode nil)
    (check-equal limit nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-list-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-list-args '("--user" "--system"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-list-args '("--local" "--online"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-list-args '("--limit" "0"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-list-args '("extra"))))
   t))

(deftest test-taf-cli-uninstall-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-uninstall-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf uninstall [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "<APP-NAME|TAF-COMMAND>") t)
    (check-equal (%taf-cli-string-contains-p help-string "VERSION-ID") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-n, --dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "-f, --force") t)
    (check-equal (%taf-cli-string-contains-p help-string "--dry-run") t)
    (check-equal (%taf-cli-string-contains-p help-string "--force") t)
    (check-equal (%taf-cli-string-contains-p help-string "install metadata") t)
    (check-equal (%taf-cli-string-contains-p help-string "SIF files") t)))

(deftest test-taf-cli-parse-taf-uninstall-args-default ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p)
      (taf.cli::%parse-taf-uninstall-args '("install-demo"))
    (check-equal mode :uninstall)
    (check-equal scope :user)
    (check-equal query "install-demo")
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)))

(deftest test-taf-cli-parse-taf-uninstall-args-artifact-command ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p)
      (taf.cli::%parse-taf-uninstall-args
       '("taf-install-demo-v0.1.0-r1"))
    (check-equal mode :uninstall)
    (check-equal scope :user)
    (check-equal query "taf-install-demo-v0.1.0-r1")
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)))

(deftest test-taf-cli-parse-taf-uninstall-args-system-force-version ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p targets)
      (taf.cli::%parse-taf-uninstall-args
       '("-s" "-n" "-f"
         "taf-install-demo" "v0.1.0-r1"))
    (check-equal mode :uninstall)
    (check-equal scope :system)
    (check-equal query "taf-install-demo")
    (check-equal version-id "v0.1.0-r1")
    (check-equal dry-run-p t)
    (check-equal force-p t)
    (check-equal (length targets) 1)
    (check-equal (getf (first targets) :query) "taf-install-demo")
    (check-equal (getf (first targets) :version-id) "v0.1.0-r1")))

(deftest test-taf-cli-parse-taf-uninstall-args-batch ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p targets)
      (taf.cli::%parse-taf-uninstall-args
       '("-n" "taf-install-a" "taf-install-b-v0.2.0-r1"))
    (check-equal mode :uninstall)
    (check-equal scope :user)
    (check-equal query "taf-install-a")
    (check-equal version-id nil)
    (check-equal dry-run-p t)
    (check-equal force-p nil)
    (check-equal (length targets) 2)
    (check-equal (getf (first targets) :query) "taf-install-a")
    (check-equal (getf (second targets) :query) "taf-install-b-v0.2.0-r1")))

(deftest test-taf-cli-parse-taf-uninstall-args-help ()
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p)
      (taf.cli::%parse-taf-uninstall-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal dry-run-p nil)
    (check-equal force-p nil)))

(deftest test-taf-cli-parse-taf-uninstall-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-uninstall-args nil)))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-uninstall-args
       '("--user" "--system" "install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-uninstall-args
       '("install-demo" "v0.1.0-r1" "extra"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-uninstall-args '("--bad" "install-demo"))))
   t))

(deftest test-taf-cli-which-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-which-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf which [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "<APP-NAME|TAF-COMMAND>") t)
    (check-equal (%taf-cli-string-contains-p help-string "VERSION-ID") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "install metadata") t)
    (check-equal (%taf-cli-string-contains-p help-string "frozen command file") t)))

(deftest test-taf-cli-parse-taf-which-args-default ()
  (multiple-value-bind (mode scope query version-id json-p)
      (taf.cli::%parse-taf-which-args '("taf-install-demo"))
    (check-equal mode :which)
    (check-equal scope :user)
    (check-equal query "taf-install-demo")
    (check-equal version-id nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-which-args-system-json-version ()
  (multiple-value-bind (mode scope query version-id json-p targets)
      (taf.cli::%parse-taf-which-args
       '("-s" "-j" "taf-install-demo" "v0.1.0-r1"))
    (check-equal mode :which)
    (check-equal scope :system)
    (check-equal query "taf-install-demo")
    (check-equal version-id "v0.1.0-r1")
    (check-equal json-p t)
    (check-equal (length targets) 1)
    (check-equal (getf (first targets) :query) "taf-install-demo")
    (check-equal (getf (first targets) :version-id) "v0.1.0-r1")))

(deftest test-taf-cli-parse-taf-which-args-batch ()
  (multiple-value-bind (mode scope query version-id json-p targets)
      (taf.cli::%parse-taf-which-args
       '("-j" "taf-install-a" "taf-install-b-v0.2.0-r1"))
    (check-equal mode :which)
    (check-equal scope :user)
    (check-equal query "taf-install-a")
    (check-equal version-id nil)
    (check-equal json-p t)
    (check-equal (length targets) 2)
    (check-equal (getf (first targets) :query) "taf-install-a")
    (check-equal (getf (second targets) :query) "taf-install-b-v0.2.0-r1")))

(deftest test-taf-cli-parse-taf-which-args-help ()
  (multiple-value-bind (mode scope query version-id json-p)
      (taf.cli::%parse-taf-which-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)
    (check-equal query nil)
    (check-equal version-id nil)
    (check-equal json-p nil)))

(deftest test-taf-cli-parse-taf-which-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-which-args nil)))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-which-args
       '("--user" "--system" "taf-install-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-which-args
       '("taf-install-demo" "v0.1.0-r1" "extra"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-which-args '("--bad" "taf-install-demo"))))
   t))

(deftest test-taf-cli-doctor-help-string-basic ()
  (taffish.i18n:with-language ("zh")
    (let ((text (taf.cli::%get-taf-doctor-help-string)))
      (check-true (search "检查的依据和处理建议" text))
      (check-equal nil (search "evidence" text))
      (check-equal nil (search "remediation" text))))
  (let ((help-string (taf.cli::%get-taf-doctor-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf doctor [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-i, --init") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--init") t)
    (check-equal (%taf-cli-string-contains-p help-string "--user") t)
    (check-equal (%taf-cli-string-contains-p help-string "--system") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--verbose") t)
    (check-equal (%taf-cli-string-contains-p help-string "--shell") t)
    (check-equal (%taf-cli-string-contains-p help-string "auto|bash|zsh|fish") t)
    (check-equal (%taf-cli-string-contains-p help-string "PATH") t)
    (check-equal (%taf-cli-string-contains-p help-string "TAFFISH_USER_HOME") t)
    (check-equal (%taf-cli-string-contains-p help-string "mksquashfs") t)
    (check-equal (%taf-cli-string-contains-p help-string "squashfuse") t)
    (check-equal (%taf-cli-string-contains-p help-string "fuse2fs") t)
    (check-equal (%taf-cli-string-contains-p help-string "gocryptfs") t)))

(deftest test-taf-cli-parse-taf-doctor-args-default ()
  (multiple-value-bind (mode init-p scope scope-seen-p)
      (taf.cli::%parse-taf-doctor-args nil)
    (check-equal mode :doctor)
    (check-equal init-p nil)
    (check-equal scope :user)
    (check-equal scope-seen-p nil)))

(deftest test-taf-cli-parse-taf-doctor-args-init-system ()
  (multiple-value-bind (mode init-p scope scope-seen-p)
      (taf.cli::%parse-taf-doctor-args '("-i" "-s"))
    (check-equal mode :doctor)
    (check-equal init-p t)
    (check-equal scope :system)
    (check-equal scope-seen-p t)))

(deftest test-taf-cli-parse-taf-doctor-args-help ()
  (multiple-value-bind (mode init-p scope scope-seen-p)
      (taf.cli::%parse-taf-doctor-args '("--help"))
    (check-equal mode :help)
    (check-equal init-p nil)
    (check-equal scope nil)
    (check-equal scope-seen-p nil)))

(deftest test-taf-cli-parse-taf-doctor-args-conflict-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-doctor-args '("--user" "--system"))))
   t))

(deftest test-taf-cli-parse-taf-doctor-args-output-and-shell ()
  (multiple-value-bind
        (mode init-p scope scope-seen-p json-p verbose-p shell)
      (taf.cli::%parse-taf-doctor-args
       '("--json" "--shell" "zsh" "--system"))
    (check-equal mode :doctor)
    (check-equal init-p nil)
    (check-equal scope :system)
    (check-equal scope-seen-p t)
    (check-equal json-p t)
    (check-equal verbose-p nil)
    (check-equal shell :zsh)))

(deftest test-taf-cli-parse-taf-doctor-args-invalid-output-error ()
  (check-true
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-doctor-args '("--json" "--verbose")))))
  (check-true
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-doctor-args '("--shell" "powershell")))))
  (check-true
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-doctor-args '("--shell"))))))

(deftest test-taf-cli-config-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-config-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf config [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--user") t)
    (check-equal (%taf-cli-string-contains-p help-string "--system") t)
    (check-equal (%taf-cli-string-contains-p help-string "TAFFISH_USER_HOME") t)
    (check-equal (%taf-cli-string-contains-p help-string "TAFFISH_CONFIG") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf config path") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf config init") t)
    (check-equal (%taf-cli-string-contains-p help-string "taf config language") t)
    (check-equal (%taf-cli-string-contains-p help-string "--show") t)
    (check-equal (%taf-cli-string-contains-p help-string "en and zh are built in") t)
    (check-equal (%taf-cli-string-contains-p help-string "do not check") t)
    (check-equal (%taf-cli-string-contains-p help-string "Examples:") t)
    (check-equal (%taf-cli-string-contains-p help-string
                                             "taf config language auto")
                 t)))

(deftest test-taf-cli-parse-taf-config-args-default ()
  (multiple-value-bind (mode scope)
      (taf.cli::%parse-taf-config-args nil)
    (check-equal mode :config)
    (check-equal scope :user)))

(deftest test-taf-cli-parse-taf-config-args-system ()
  (multiple-value-bind (mode scope)
      (taf.cli::%parse-taf-config-args '("-s"))
    (check-equal mode :config)
    (check-equal scope :system)))

(deftest test-taf-cli-parse-taf-config-args-path ()
  (multiple-value-bind (mode scope profile force-p)
      (taf.cli::%parse-taf-config-args '("path" "-s"))
    (check-equal mode :path)
    (check-equal scope :system)
    (check-equal profile :github)
    (check-equal force-p nil)))

(deftest test-taf-cli-parse-taf-config-args-init-china-force ()
  (multiple-value-bind (mode scope profile force-p)
      (taf.cli::%parse-taf-config-args '("init" "--china" "--force"))
    (check-equal mode :init)
    (check-equal scope :user)
    (check-equal profile :china)
    (check-equal force-p t)))

(deftest test-taf-cli-parse-taf-config-language-show ()
  (multiple-value-bind (mode scope profile force-p language)
      (taf.cli::%parse-taf-config-args '("language" "--show" "--system"))
    (check-equal mode :language)
    (check-equal scope :system)
    (check-equal profile :github)
    (check-equal force-p nil)
    (check-equal language nil)))

(deftest test-taf-cli-parse-taf-config-language-value ()
  (multiple-value-bind (mode scope profile force-p language)
      (taf.cli::%parse-taf-config-args '("language" "zh" "--user"))
    (check-equal mode :language)
    (check-equal scope :user)
    (check-equal profile :github)
    (check-equal force-p nil)
    (check-equal language "zh")))

(deftest test-taf-cli-parse-taf-config-args-help ()
  (multiple-value-bind (mode scope)
      (taf.cli::%parse-taf-config-args '("--help"))
    (check-equal mode :help)
    (check-equal scope nil)))

(deftest test-taf-cli-parse-taf-config-args-conflict-error ()
	  (check-equal
	   (%taf-cli-signal-error-p
	    (lambda ()
	      (taf.cli::%parse-taf-config-args '("--user" "--system"))))
	   t)
	  (check-equal
	   (%taf-cli-signal-error-p
	    (lambda ()
	      (taf.cli::%parse-taf-config-args '("path" "init"))))
	   t)
	  (check-equal
	   (%taf-cli-signal-error-p
	    (lambda ()
	      (taf.cli::%parse-taf-config-args '("init" "--github" "--china"))))
	   t)
	  (check-true
	   (%taf-cli-signal-error-p
	    (lambda ()
	      (taf.cli::%parse-taf-config-args
	       '("language" "--show" "zh")))))
	  (check-true
	   (%taf-cli-signal-error-p
	    (lambda ()
	      (taf.cli::%parse-taf-config-args
	       '("language" "zh" "--force"))))))

(deftest test-taf-cli-history-help-string-basic ()
  (let ((help-string (taf.cli::%get-taf-history-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf history [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-l, --last") t)
    (check-equal (%taf-cli-string-contains-p help-string "-i, --id") t)
    (check-equal (%taf-cli-string-contains-p help-string "-j, --json") t)
    (check-equal (%taf-cli-string-contains-p help-string "-p, --path") t)
    (check-equal (%taf-cli-string-contains-p help-string "-c, --clear") t)
    (check-equal (%taf-cli-string-contains-p help-string "--last") t)
    (check-equal (%taf-cli-string-contains-p help-string "--id") t)
    (check-equal (%taf-cli-string-contains-p help-string "--json") t)
    (check-equal (%taf-cli-string-contains-p help-string "--path") t)
    (check-equal (%taf-cli-string-contains-p help-string "--clear") t)
    (check-equal (%taf-cli-string-contains-p help-string "history.jsonl") t)))

(deftest test-taf-cli-history-help-string-hides-record-exec ()
  (let ((help-string (taf.cli::%get-taf-history-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "--record-exec") nil)))

(deftest test-taf-cli-parse-taf-history-args-default ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args nil)
    (check-equal mode :history)
    (check-equal last 20)
    (check-equal id nil)
    (check-equal json-p nil)
    (check-equal path-p nil)
    (check-equal clear-p nil)))

(deftest test-taf-cli-parse-taf-history-args-last-json ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args '("-l" "5" "-j"))
    (check-equal mode :history)
    (check-equal last 5)
    (check-equal id nil)
    (check-equal json-p t)
    (check-equal path-p nil)
    (check-equal clear-p nil)))

(deftest test-taf-cli-parse-taf-history-args-id-json ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args '("-i" "RUN-1" "-j"))
    (check-equal mode :history)
    (check-equal last 20)
    (check-equal id "RUN-1")
    (check-equal json-p t)
    (check-equal path-p nil)
    (check-equal clear-p nil)))

(deftest test-taf-cli-parse-taf-history-args-path ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args '("-p"))
    (check-equal mode :history)
    (check-equal last 20)
    (check-equal id nil)
    (check-equal json-p nil)
    (check-equal path-p t)
    (check-equal clear-p nil)))

(deftest test-taf-cli-parse-taf-history-args-clear ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args '("-c"))
    (check-equal mode :history)
    (check-equal last 20)
    (check-equal id nil)
    (check-equal json-p nil)
    (check-equal path-p nil)
    (check-equal clear-p t)))

(deftest test-taf-cli-parse-taf-history-args-help ()
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (taf.cli::%parse-taf-history-args '("--help"))
    (check-equal mode :help)
    (check-equal last nil)
    (check-equal id nil)
    (check-equal json-p nil)
    (check-equal path-p nil)
    (check-equal clear-p nil)))

(deftest test-taf-cli-parse-taf-history-record-exec ()
  (multiple-value-bind (mode record)
      (taf.cli::%parse-taf-history-args
       '("--record-exec"
         "--status" "success"
         "--command" "taf-demo-v0.1.0-r1"
         "--project-name" "demo"
         "--project-kind" "flow"
         "--project-version" "0.1.0"
         "--project-release" "1"
         "--project-command" "taf-demo"
         "--project-root" "/tmp/demo/target/.taf-demo-v0.1.0-r1"
         "--project-main" "/tmp/demo/target/.taf-demo-v0.1.0-r1/src/main.taf"
         "--repository-url" "https://github.com/taffish/demo"
         "--container-image" ""
         "--snapshot-root" "/tmp/demo/target/.taf-demo-v0.1.0-r1"
         "--cwd" "/tmp/demo"
         "--stage" "run"
         "--exit-code" "0"
         "--" "--alpha" "beta"))
    (check-equal mode :record-exec)
    (check-equal (getf record :event) "exec")
    (check-equal (getf record :status) "success")
    (check-equal (getf record :command) "taf-demo-v0.1.0-r1")
    (check-equal (getf record :args) '("--alpha" "beta"))
    (check-equal (getf record :cwd) "/tmp/demo")
    (check-equal (getf record :exit-code) 0)
    (check-equal (getf (getf record :project) :name) "demo")
    (check-equal (getf (getf record :project) :command-name) "taf-demo")
    (check-equal (getf (getf record :project) :container-image) nil)
    (check-equal (getf (getf record :extra) :stage) "run")))

(deftest test-taf-cli-parse-taf-history-args-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--last" "0"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--last"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--id"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--path" "--json"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--clear" "--last" "2"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args '("--path" "--clear"))))
   t))

(deftest test-taf-cli-parse-taf-history-record-exec-error ()
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args
       '("--record-exec" "--command" "taf-demo" "--exit-code" "0"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args
       '("--record-exec" "--status" "success" "--exit-code" "0"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args
       '("--record-exec" "--status" "success" "--command" "taf-demo"))))
   t)
  (check-equal
   (%taf-cli-signal-error-p
    (lambda ()
      (taf.cli::%parse-taf-history-args
       '("--record-exec" "--status" "success" "--command" "taf-demo"
         "--exit-code" "-1"))))
   t))

(deftest test-taf-cli-publish-no-latest-policy ()
  (multiple-value-bind (mode dry-run build-p channel prompt-p create-repo-p
                       visibility release-p lock-repo-p)
      (taf.cli::%parse-taf-publish-args '("--no-latest" "-y" "-b" "-r"))
    (check-equal :publish mode)
    (check-false dry-run)
    (check-true build-p)
    (check-equal :no-latest channel)
    (check-false prompt-p)
    (check-false create-repo-p)
    (check-equal :public visibility)
    (check-true release-p)
    (check-true lock-repo-p))
  (dolist (args '(("--latest" "--no-latest") ("--no-latest" "--latest")
                  ("--pre" "--no-latest") ("--no-latest" "--pre")
                  ("--latest" "--pre") ("--pre" "--latest")))
    (check-true (%taf-cli-signal-error-p
                 (lambda () (taf.cli::%parse-taf-publish-args args))))))

(deftest test-taf-cli-publish-policy-help-bilingual ()
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (let ((help (taf.cli::%get-taf-publish-help-string)))
        (dolist (option '("--latest" "--pre" "--no-latest" "--release" "--yes"))
          (check-true (search option help)))
        (check-false (search "Require a version newer" help))
        (check-false (search "要求版本比远端最新版本更新" help))))))

(deftest test-taf-cli-doctor-specialized-parsing ()
  (let ((values (multiple-value-list
                 (taf.cli::%parse-taf-doctor-args '("hub" "abricate" "--system" "--json")))))
    (check-equal :system (third values))
    (check-equal :hub (eighth values))
    (check-equal '("abricate") (ninth values)))
  (check-equal :index (nth-value 7 (taf.cli::%parse-taf-doctor-args '("--user" "index"))))
  (dolist (args '(("hub" "--init") ("index" "--shell" "auto") ("index" "app") ("hub" "--repair")))
    (check-true (%taf-cli-signal-error-p (lambda () (taf.cli::%parse-taf-doctor-args args))))))

(deftest test-taf-cli-all-installed-repair-options ()
  (dolist (extra '(nil ("--yes" "--system") ("--json" "--tools")
                   ("--dry-run" "--flows") ("--kind" "all")))
    (let ((values (multiple-value-list
                   (taf.cli::%parse-taf-install-args
                    (append '("--all-installed" "--repair") extra)))))
      (check-equal :install-all (first values))
      (check-false (nth 9 values))
      (check-true (nth 14 values))
      (check-true (nth 15 values))))
  (check-false (nth-value 15 (taf.cli::%parse-taf-install-args '("--all" "--repair"))))
  (dolist (args '(("--all-installed") ("--all-installed" "--yes")
                  ("--all-installed" "--repair" "--all")
                  ("--all-installed" "--repair" "demo")
                  ("--all-installed" "--repair" "--force")
                  ("--all-installed" "--repair" "--from" ".")
                  ("--all-installed" "--repair" "--prune-old")
                  ("--all-installed" "--repair" "--yes" "--dry-run")))
    (check-true (%taf-cli-signal-error-p (lambda () (taf.cli::%parse-taf-install-args args)))))
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (check-true (search "--all-installed" (taf.cli::%get-taf-install-help-string))))))

(deftest test-taf-cli-install-repair-options-and-compatibility ()
  (dolist (args '(("demo" "--repair") ("--repair" "--all")
                  ("--all" "--repair" "--yes" "--system")
                  ("--all" "--tools" "--repair" "--json")
                  ("demo" "1-r1" "--repair" "--dry-run")))
    (check-true (nth-value 14 (taf.cli::%parse-taf-install-args args))))
  (check-false (nth-value 14 (taf.cli::%parse-taf-install-args '("demo"))))
  (dolist (args '(("demo" "--repair" "--force") ("--repair" "--from" ".")
                  ("--all" "--repair" "--prune-old") ("demo" "--repair" "--yes")))
    (check-true (%taf-cli-signal-error-p (lambda () (taf.cli::%parse-taf-install-args args)))))
  (dolist (language '("en" "zh"))
    (taffish.i18n:with-language (language)
      (check-true (search "--repair" (taf.cli::%get-taf-install-help-string)))
      (check-true (search "index.latest" (taf.cli::%get-taf-install-help-string)))
      (check-true (search "stderr" (taf.cli::%get-taf-doctor-help-string))))))
