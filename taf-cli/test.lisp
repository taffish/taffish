(in-package :han.test)

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

(deftest test-taf-cli-version-string-basic ()
  (check-equal (stringp taf.cli:*taf-version*) t)
  (check-equal (%taf-cli-string-contains-p taf.cli:*taf-version* "taf") t)
  (check-equal (%taf-cli-string-contains-p taf.cli:*taf-version* "0.8.0") t)
  (check-equal taf.cli:*taf-version*
               "taf 0.8.0 (2026-05, Kaiyuan Han)"))

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
    (check-equal (%taf-cli-string-contains-p help-string "main .taf") t)))

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
    (check-equal (%taf-cli-string-contains-p help-string "fail fast") t)))

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
    (check-equal (%taf-cli-string-contains-p help-string "searching upward") t)
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
   t))

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
  (let ((help-string (taf.cli::%get-taf-doctor-help-string)))
    (check-equal (%taf-cli-string-contains-p help-string "taf doctor [-h | --help]") t)
    (check-equal (%taf-cli-string-contains-p help-string "-i, --init") t)
    (check-equal (%taf-cli-string-contains-p help-string "-u, --user") t)
    (check-equal (%taf-cli-string-contains-p help-string "-s, --system") t)
    (check-equal (%taf-cli-string-contains-p help-string "--init") t)
    (check-equal (%taf-cli-string-contains-p help-string "--user") t)
    (check-equal (%taf-cli-string-contains-p help-string "--system") t)
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
    (check-equal (%taf-cli-string-contains-p help-string "do not check") t)))

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
	   t))

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
