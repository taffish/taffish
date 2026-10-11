(in-package :taf.cli)

;;;; ============================================================
;;;; run.lisp
;;;; ============================================================

;;;; ------------------------------------------------------------
;;;; run: version
;;;; ------------------------------------------------------------

(defparameter *taf-version*
  "taf         0.11.0")

(defun run-taf-version ()
  (format t "~A~%" *taf-version*))

(defun %record-taf-history-event (&rest args)
  (apply #'taf.core:system-record-history-event
         (append args
                 (list :taf-version *taf-version*
                       :safe t))))

(defun %taf-option-p (arg &rest names)
  (member arg names :test #'string-equal))

;;;; ------------------------------------------------------------
;;;; run: help
;;;; ------------------------------------------------------------

(defun %format-split-line (length &optional (char #\-))
  (let ((len (if (stringp length)
                 (length length)
                 (if (numberp length)
                     length
                     (error "LENGTH must be NUMBER or STRING, but got: ~S"
                            (type-of length))))))
    (dotimes (i len)
      (format t "~A" char))
    (format t "~%")))

(defun %get-taf-help-string-english ()
  "Manage TAFFISH projects, installed apps, and the local environment.

Usage:
  taf <COMMAND> [ARGS...]
  taf help [COMMAND]
  taf <COMMAND> [-h | --help]
  taf [-h | --help]
  taf [-v | --version]

Project commands:
  new         Create a tool or flow project
  check       Check the current project
  compile     Print the project's shell code without running it
  build       Build a versioned command; optionally build a container image
  run         Compile and run the current project
  publish     Publish to GitHub or resume an interrupted publish

Hub commands:
  update      Refresh the local index without upgrading apps
  search      Search apps in the local index
  info        Show indexed app/version information
  install     Install from the index or a local project
  outdated    Check installed apps for updates using the local index
  upgrade     Upgrade installed apps using the local index
  prune       Remove old versions that are safe to prune
  uninstall   Uninstall installed apps
  list        List installed or indexed apps
  which       Show installed command paths and metadata

System commands:
  doctor      Diagnose the environment and local installs; read-only by default
  config      Show or manage runtime configuration
  history     Show or clear execution history

Getting started:
  taf update                  Fetch the app index
  taf install fastqc          Install an app
  taf help install            Show command options and examples

Language:
  taf config language         Show current and available languages
  taf config language zh      Chinese; en: English; auto: host locale [default]

More information:
  Website: https://taffish.com
  Hub: https://taffish.github.io/
  Support: support@taffish.com")

(defun %get-taf-command-help-string (command)
  (let ((cmd (and command
                  (string-trim '(#\Space #\Tab) command))))
    (cond
      ((or (null cmd)
           (string= cmd "")
           (member cmd '("-h" "--help" "help") :test #'string-equal))
       (%get-taf-help-string))
      ((member cmd '("-v" "--version" "version") :test #'string-equal)
       *taf-version*)
      ;; project
      ((string= cmd "new") (%get-taf-new-help-string))
      ((string= cmd "check") (%get-taf-check-help-string))
      ((string= cmd "compile") (%get-taf-compile-help-string))
      ((string= cmd "build") (%get-taf-build-help-string))
      ((string= cmd "run") (%get-taf-run-help-string))
      ((string= cmd "publish") (%get-taf-publish-help-string))
      ;; hub
      ((string= cmd "update") (%get-taf-update-help-string))
      ((string= cmd "search") (%get-taf-search-help-string))
      ((string= cmd "info") (%get-taf-info-help-string))
      ((string= cmd "install") (%get-taf-install-help-string))
      ((string= cmd "outdated") (%get-taf-outdated-help-string))
      ((string= cmd "upgrade") (%get-taf-upgrade-help-string))
      ((string= cmd "prune") (%get-taf-prune-help-string))
      ((string= cmd "uninstall") (%get-taf-uninstall-help-string))
      ((string= cmd "list") (%get-taf-list-help-string))
      ((string= cmd "which") (%get-taf-which-help-string))
      ;; system
      ((string= cmd "doctor") (%get-taf-doctor-help-string))
      ((string= cmd "config") (%get-taf-config-help-string))
      ((string= cmd "history") (%get-taf-history-help-string))
      (t
       (error "~A~%~A"
              (%taf-help-unknown-command-message command)
              (%taf-cli-message "list-commands"))))))

(defun run-taf-help (&optional raw-args)
  (cond
    ((null raw-args)
     (format t "~A~%" *taf-version*)
     (%format-split-line *taf-version* #\-)
     (format t "~A~%" (%get-taf-help-string)))
    ((null (cdr raw-args))
     (format t "~A~%" (%get-taf-command-help-string (car raw-args))))
    (t
     (error "~A~%~A"
            (%taf-help-too-many-message raw-args)
            (%get-taf-help-string)))))

;;;; ------------------------------------------------------------
;;;; run: project: new
;;;; ------------------------------------------------------------

(defun %get-taf-new-help-string-english ()
  (format nil "Usage:
  taf new [-h | --help]
  taf new <APP-NAME> [OPTIONS]

Create a new TAFFISH app project.

Generated files include an ignored release.md draft for `taf publish --release`.

Options:
  -t, --tool                Create a tool project
  -f, --flow                Create a flow project [default]
  -v, --version <VERSION>   Set version, default 0.1.0
  -r, --release <RELEASE>   Set release, default 1
  -l, --license <LICENSE>   Set license template, default Apache-2.0
  -g, --repo <URL>          Set repository URL
                            [https://~A/~A/<APP-NAME>]
  -i, --image <IMAGE>       Set container image
  -d, --docker              Create docker/Dockerfile and add container metadata
                            and GitHub Actions workflow
                            [~A/~A/<APP-NAME>:<VERSION>-r<RELEASE>]
      --no-actions          Do not create GitHub Actions workflow for --docker
  -h, --help                Show this help"
          taf.core:*default-github-host*
          taf.core:*default-github-owner*
          taf.core:*default-container-registry*
          taf.core:*default-github-owner*))

(defun %parse-taf-new-args (new-args)
  (values (car new-args)
          (cdr new-args)))

(defun run-taf-new (raw-args)
  (multiple-value-bind (name args)
      (%parse-taf-new-args raw-args)
    (cond
      ((null name)
       (%taf-cli-error-with-help "project-name-missing"
                                 (%get-taf-new-help-string)))
      ((member name '("-h" "--help") :test #'string-equal)
       (format t "~A~%" (%get-taf-new-help-string)))
      (t
       (taf.core:project-new name args)))))

;;;; ------------------------------------------------------------
;;;; run: project: check
;;;; ------------------------------------------------------------

(defun %get-taf-check-help-string-english ()
  "Usage:
  taf check [-h | --help]
  taf check

Check the current TAFFISH app project.

Details:
  - finds taffish.toml from current directory upward
  - validates required files and package/repository/command metadata
  - validates container, build and smoke metadata for containerized projects
  - parses the main .taf file and checks dependency/image consistency
  - reports project summary

Options:
  -h, --help                Show this help")

(defun run-taf-check (raw-args)
  (cond
    ((null raw-args)
     (taf.core:project-check))
    ((and (null (cdr raw-args))
          (member (car raw-args) '("-h" "--help") :test #'string-equal))
     (format t "~A~%" (%get-taf-check-help-string)))
    (t
     (%taf-cli-error-with-help "no-arguments"
                               (%get-taf-check-help-string)
                               :command "check"))))

;;;; ------------------------------------------------------------
;;;; run: project: compile
;;;; ------------------------------------------------------------

(defun %get-taf-compile-help-string-english ()
  "Usage:
  taf compile [-h | --help]
  taf compile [ARGS...]
  taf compile -- [ARGS...]

Compile the current TAFFISH app project to shell code.

Details:
  - finds taffish.toml from current directory upward
  - reads [package].main as the project main .taf file
  - forwards ARGS to that .taf program
  - prints generated shell code to STDOUT

Options:
  -h, --help                Show this help

Note:
  Use `taf compile -- -h` if you want to pass -h to the .taf program.")

(defun %parse-taf-compile-args (raw-args)
  (cond
    ((null raw-args)
     (values :compile nil))
    ((and (null (cdr raw-args))
          (member (car raw-args) '("-h" "--help") :test #'string-equal))
     (values :help nil))
    ((string= (car raw-args) "--")
     (values :compile (cdr raw-args)))
    (t
     (values :compile raw-args))))

(defun run-taf-compile (raw-args)
  (multiple-value-bind (mode args)
      (%parse-taf-compile-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-compile-help-string)))
      (:compile
       (format t "~A" (taf.core:project-compile args)))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "compile"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: project: build
;;;; ------------------------------------------------------------

(defun %get-taf-build-help-string-english ()
  "Usage:
  taf build [-h | --help]
  taf build
  taf build [-i | --image | -d | --docker] [-b | --backend <docker|podman>]
  taf build [-a | --all] [-b | --backend <docker|podman>]

Build the current TAFFISH app project.

Details:
  - with no options, builds the versioned command wrapper only
  - --image/--docker builds only the container image
  - --all builds both the command wrapper and container image
  - stores frozen source snapshot under target/.<artifact>

Options:
  -i, --image                  Build container image only
  -d, --docker                 Build container image only
  -a, --all                    Build container image and command wrapper
  -b, --backend <docker|podman>
                               Select image build backend
  -h, --help                   Show this help

Generated command:
  target/<command-name>-v<version>-r<release>

The generated command uses that frozen snapshot instead of live src files.")

(defun %parse-taf-build-args (raw-args)
  (let ((command-p t)
        (image-p nil)
        (backend nil))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (values :build command-p image-p backend))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil))
                 ((%taf-option-p (car args) "-i" "--image" "-d" "--docker")
                  (setf command-p nil
                        image-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-a" "--all")
                  (setf command-p t
                        image-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-b" "--backend")
                  (unless (cadr args)
                    (%taf-cli-error "backend-build"))
                  (setf backend (cadr args))
                  (parse (cddr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-message "build" (car args))
                         (%get-taf-build-help-string))))))
      (parse raw-args))))

(defun run-taf-build (raw-args)
  (multiple-value-bind (mode command-p image-p backend)
      (%parse-taf-build-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-build-help-string)))
      (:build
       (let ((result (taf.core:project-build :command-p command-p
                                             :image-p image-p
                                             :backend backend)))
         (%record-taf-history-event
          :event "build"
          :status "success"
          :project (getf result :project)
          :cwd (han.os:current-directory)
          :backend backend
          :extra (list :build-command command-p
                       :build-image image-p
                       :command-file (getf (getf result :command) :command-file)
                       :image (getf (getf result :image) :image)
                       :image-backend (getf (getf result :image) :backend)))
         result))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "build"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: project: run
;;;; ------------------------------------------------------------

(defun %get-taf-run-help-string-english ()
  "Usage:
  taf run [-h | --help]
  taf run [-b | --backend <docker|podman|apptainer>] [ARGS...]
  taf run [-b | --backend <docker|podman|apptainer>] -- [ARGS...]

Compile and run the current TAFFISH app project.

Details:
  - finds taffish.toml from current directory upward
  - compiles [package].main to a temporary shell file
  - runs that shell file with STDOUT/STDERR inherited
  - passes STDIN only when current STDIN is pipe/file input
  - forwards ARGS to the .taf program
  - TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker is used when
    --backend is not given
  - TAFFISH_DOCKER_RUN_ARGS, TAFFISH_PODMAN_RUN_ARGS, and
    TAFFISH_APPTAINER_RUN_ARGS append local backend-specific runtime args

Options:
  -b, --backend <docker|podman|apptainer>
                            Force generic <container:...> tags to use backend
  -h, --help                Show this help

Note:
  Use `--` before ARGS when the .taf program needs option-like arguments,
  for example `taf run -- -h` or `taf run -- --backend value`.")

(defun %standard-input-terminal-p ()
  (han.host:standard-input-terminal-p))

(defun %taf-run-input ()
  (if (%standard-input-terminal-p)
      nil
      t))

(defun %parse-taf-run-args (raw-args)
  (let ((backend nil))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (values :run nil backend))
                 ((and (null (cdr args))
                       (null backend)
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil))
                 ((string= (car args) "--")
                  (values :run (cdr args) backend))
                 ((%taf-option-p (car args) "-b" "--backend")
                  (unless (cadr args)
                    (%taf-cli-error "backend-run"))
                  (setf backend (cadr args))
                  (parse (cddr args)))
                 (t
                  (values :run args backend)))))
      (parse raw-args))))

(defun run-taf-run (raw-args)
  (multiple-value-bind (mode args backend)
      (%parse-taf-run-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-run-help-string)))
      (:run
       (let* ((project (ignore-errors
                         (taf.core:project-check (han.os:current-directory) nil)))
              (result (taf.core:project-run
                       :args args
                       :container-backend backend
                       :input (%taf-run-input)))
              (exit-code (getf result :exit-code)))
         (%record-taf-history-event
          :event "run"
          :status (if (and (integerp exit-code) (= exit-code 0))
                      "success"
                      "failure")
          :project project
          :command (and project (getf project :command-name))
          :args args
          :cwd (han.os:current-directory)
          :backend backend
          :exit-code exit-code)
         (unless (and (integerp exit-code) (= exit-code 0))
           (han.host:quit (or exit-code 1)))))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "run"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: project: publish
;;;; ------------------------------------------------------------

(defun %get-taf-publish-help-string-english ()
  "Usage:
  taf publish [-h | --help]
  taf publish [-n | --dry-run] [--latest | --pre | --no-latest] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]
  taf publish [-y | --yes] [--latest | --pre | --no-latest] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]

Publish the current TAFFISH app project to its GitHub repository.

Details:
  - runs taf check first
  - reads [repository].url from taffish.toml
  - checks remote tags named v<version>-r<release>
  - remote git checks are non-interactive unless --prompt is given
  - with --release, reads release.md and creates a GitHub release
  - versions need not increase; an existing tag cannot be reused for different content
  - without --release, only publishes Git tags; channel options do not set
    GitHub Latest or Pre-release status
  - can create the GitHub repository when --create-repo is given
  - newly created repositories are locked by default:
    immutable releases are enabled and v* tags are protected from update/delete
  - with --build, ensures an exact versioned wrapper and frozen snapshot before
    establishing the release commit; unchanged valid artifacts are not rewritten
  - after an interruption, rerun the same command; matching repository, tag,
    and release stages are skipped, including a repository already created by
    --create-repo
  - once a matching release commit or tag identity is established, a resumed
    --build publish verifies that identity and skips rebuilding
  - a matching completed publish is a successful no-op for publish mutations
    and does not reclaim Latest from a later release
  - rejects conflicting commits, tags, releases, or changed publish intent
  - commits, tags, pushes and optional release creation only when --yes is given

Options:
  -n, --dry-run              Print publish plan only [default]
  -y, --yes                  Run publish actions: commit, tag, push and release
  -b, --build                Idempotently ensure command wrapper before publish
  -r, --release              Read release.md from project root:
                              first line becomes publish message;
                              whole file becomes GitHub release notes
  --latest                  Mark the new GitHub Release as Latest [default]
  --pre                     Create a GitHub Pre-release, not Latest
  --no-latest               Create a formal GitHub Release without setting Latest
  --create-repo              Create GitHub repository if it is missing
  --public                   Create missing repository as public [default]
  --private                  Create missing repository as private
  --no-lock-repo             Do not lock a newly created repository
  --prompt                   Allow git to ask credentials through terminal
  -h, --help                 Show this help

Note:
  TAF does not manage GitHub login. Without --prompt, remote git commands
  fail fast instead of asking for credentials.
  --latest, --pre and --no-latest are mutually exclusive. Retry with the same
  options and release.md; publish never changes an existing Release's type.")

(defun %parse-taf-publish-args (raw-args)
  (let ((dry-run t)
        (build-p nil)
        (channel :latest)
        (dry-run-seen-p nil)
        (yes-seen-p nil)
        (latest-seen-p nil)
        (pre-seen-p nil)
        (no-latest-seen-p nil)
        (create-repo-p nil)
        (repo-visibility :public)
        (public-seen-p nil)
        (private-seen-p nil)
        (prompt-p nil)
        (release-p nil)
        (lock-repo-p t))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (when (and dry-run-seen-p yes-seen-p)
                    (%taf-cli-error "conflict" :command "publish"
                                    :left "--dry-run" :right "--yes"))
                  (when (and latest-seen-p pre-seen-p)
                    (%taf-cli-error "conflict" :command "publish"
                                    :left "--latest" :right "--pre"))
                  (when (and no-latest-seen-p (or latest-seen-p pre-seen-p))
                    (%taf-cli-error "conflict" :command "publish"
                                    :left "--no-latest"
                                    :right (if latest-seen-p "--latest" "--pre")))
                  (when (and public-seen-p private-seen-p)
                    (%taf-cli-error "conflict" :command "publish"
                                    :left "--public" :right "--private"))
                  (values :publish dry-run build-p channel
                          prompt-p create-repo-p repo-visibility
                          release-p lock-repo-p))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-n" "--dry-run")
                  (setf dry-run t
                        dry-run-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-y" "--yes")
                  (setf dry-run nil
                        yes-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-b" "--build")
                  (setf build-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-r" "--release")
                  (setf release-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--latest")
                  (setf channel :latest
                        latest-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--pre")
                  (setf channel :pre
                        pre-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--no-latest")
                  (setf channel :no-latest
                        no-latest-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--create-repo")
                  (setf create-repo-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--public")
                  (setf repo-visibility :public
                        public-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--private")
                  (setf repo-visibility :private
                        private-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--no-lock-repo")
                  (setf lock-repo-p nil)
                  (parse (cdr args)))
                 ((string= (car args) "--prompt")
                  (setf prompt-p t)
                  (parse (cdr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-message "publish" (car args))
                         (%get-taf-publish-help-string))))))
      (parse raw-args))))

(defun run-taf-publish (raw-args)
  (multiple-value-bind
        (mode dry-run build-p channel prompt-p create-repo-p repo-visibility
         release-p lock-repo-p)
      (%parse-taf-publish-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-publish-help-string)))
      (:publish
       (taf.core:project-publish :dry-run dry-run
                                 :build-p build-p
                                 :channel channel
                                 :prompt-p prompt-p
                                 :create-repo-p create-repo-p
                                 :repo-visibility repo-visibility
                                 :lock-repo-p lock-repo-p
                                 :release-p release-p))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "publish"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: update
;;;; ------------------------------------------------------------

(defun %get-taf-update-help-string-english ()
  "Usage:
  taf update [-h | --help]
  taf update [-u | --user | -s | --system] [--url <INDEX-URL>] [-y | --yes]

Update the local TAFFISH index cache.

Details:
  - downloads a static TAFFISH index JSON file
  - writes index/current.json for the selected scope
  - writes a timestamped copy under index/snapshots/
  - reads TAFFISH_INDEX_URL when --url is not given
  - defaults to the official TAFFISH index

Options:
  -u, --user                Update user index [default]
  -s, --system              Update system index
  --url <INDEX-URL>         Override index URL or local index file
  -y, --yes                 Accepted for non-interactive compatibility
  -h, --help                Show this help")

(defun %parse-taf-update-args (raw-args)
  (let ((scope :user)
        (index-url nil)
        (yes-p nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "update" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "update"
                                    :left "--user" :right "--system"))
                  (values :update scope index-url yes-p))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--url")
                  (setf index-url (require-value args "--url"))
                  (parse (cddr args)))
                 ((member (car args) '("-y" "--yes") :test #'string-equal)
                  (setf yes-p t)
                  (parse (cdr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-message "update" (car args))
                         (%get-taf-update-help-string))))))
      (parse raw-args))))

(defun run-taf-update (raw-args)
  (multiple-value-bind (mode scope index-url yes-p)
      (%parse-taf-update-args raw-args)
    (declare (ignore yes-p))
    (case mode
      (:help
       (format t "~A~%" (%get-taf-update-help-string)))
      (:update
       (taf.core:hub-update :scope scope
                            :index-url index-url))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "update"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: search
;;;; ------------------------------------------------------------

(defun %get-taf-search-help-string-english ()
  "Usage:
  taf search [-h | --help]
  taf search [-u | --user | -s | --system] [-j | --json]
             [-l | --limit <N>] <KEYWORD...>

Search TAFFISH apps from the local index.

Details:
  - reads index/current.json for the selected scope
  - matches package names, command names, kind, version, repository and image
  - treats multiple keywords as AND terms
  - defaults to showing 20 results
  - run `taf update` first if the local index is missing

Options:
  -u, --user                Read user index [default]
  -s, --system              Read system index
  -j, --json                Print search results as JSON
  -l, --limit <N>           Limit result count, default 20
  -h, --help                Show this help")

(defun %parse-taf-search-positive-integer (value option-name)
  (let ((n (and value
                (ignore-errors
                  (parse-integer value :junk-allowed nil)))))
    (unless (and n (> n 0))
      (%taf-cli-error "requires-positive-integer"
                      :command "search"
                      :option option-name
                      :value (%taf-cli-repr value)))
    n))

(defun %parse-taf-search-args (raw-args)
  (let ((scope :user)
        (json-p nil)
        (limit taf.core::*hub-search-default-limit*)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "search" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "search"
                                    :left "--user" :right "--system"))
                  (when (null positionals)
                    (%taf-cli-error-with-help
                     "keyword-missing"
                     (%get-taf-search-help-string)
                     ))
                  (values :search
                          scope
                          (format nil "~{~A~^ ~}" (nreverse positionals))
                          limit
                          json-p))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-l" "--limit")
                  (setf limit
                        (%parse-taf-search-positive-integer
                         (require-value args "--limit")
                         "--limit"))
                  (parse (cddr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-search-help-string)
                                            :command "search"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "search" (car args))
                         (%get-taf-search-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-search (raw-args)
  (multiple-value-bind (mode scope query limit json-p)
      (%parse-taf-search-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-search-help-string)))
      (:search
       (taf.core:hub-search :scope scope
                            :query query
                            :limit limit
                            :json-p json-p))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "search"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: info
;;;; ------------------------------------------------------------

(defun %taf-hub-version-id-string-p (value)
  (when (and (stringp value)
             (> (length value) 0))
    (let* ((string (if (and (> (length value) 1)
                            (char= (char value 0) #\v))
                       (subseq value 1)
                       value))
           (split (search "-r" string :from-end t :test #'char=)))
      (and split
           (> split 0)
           (not (search "-v" string :test #'char=))
           (some #'digit-char-p (subseq string 0 split))
           (< (+ split 2) (length string))
           (every #'digit-char-p (subseq string (+ split 2)))))))

(defun %taf-hub-targets-from-positionals (positionals label help-string)
  (let ((items (nreverse positionals)))
    (cond
      ((null items)
       (%taf-cli-error-with-help "target-missing" help-string
                                 :command label))
      ((and (= (length items) 2)
            (%taf-hub-version-id-string-p (second items)))
       (list (list :query (first items)
                   :version-id (second items))))
      ((some #'%taf-hub-version-id-string-p items)
       (%taf-cli-error-with-help "standalone-version-batch" help-string
                                 :command label))
      (t
       (mapcar (lambda (item)
                 (list :query item :version-id nil))
               items)))))

(defun %taf-hub-targets-from-optional-positionals (positionals label help-string)
  (if positionals
      (%taf-hub-targets-from-positionals positionals label help-string)
      nil))

(defun %taf-hub-parse-kind (value label)
  (cond
    ((null value) :all)
    ((member value '("tool" "tools") :test #'string-equal) :tool)
    ((member value '("flow" "flows") :test #'string-equal) :flow)
    ((string-equal value "all") :all)
    (t
     (%taf-cli-error "kind"
                     :command label
                     :value (%taf-cli-repr value)))))

(defun %get-taf-info-help-string-english ()
  "Usage:
  taf info [-h | --help]
  taf info [-u | --user | -s | --system] [-j | --json]
           <APP-NAME|TAF-COMMAND>...
  taf info [-u | --user | -s | --system] [-j | --json]
           <APP-NAME|TAF-COMMAND> <VERSION-ID>

Show TAFFISH app information from the local index.

Details:
  - reads index/current.json for the selected scope
  - shows package latest version and all indexed versions
  - accepts package names, for example my-tool
  - accepts command names, for example taf-my-tool
  - accepts exact versioned command names, for example taf-my-tool-v0.1.0-r1
  - accepts multiple app/command targets in one command
  - defaults to the package latest version when VERSION-ID is omitted
  - accepts VERSION-ID with or without leading v, for example 0.1.0-r1
  - for batch exact versions, prefer exact versioned command names
  - --json prints one object for one target and an array for multiple targets
  - run `taf update` first if the local index is missing

Options:
  -u, --user                Read user index [default]
  -s, --system              Read system index
  -j, --json                Print resolved version record as JSON
  -h, --help                Show this help")

(defun %parse-taf-info-args (raw-args)
  (let ((scope :user)
        (json-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (parse (args)
               (cond
                ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "info"
                                    :left "--user" :right "--system"))
                  (let* ((targets
                           (%taf-hub-targets-from-positionals
                            positionals
                            "info"
                            (%get-taf-info-help-string)))
                         (first-target (first targets)))
                    (values :info
                            scope
                            (getf first-target :query)
                            (getf first-target :version-id)
                            json-p
                            targets)))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-info-help-string)
                                            :command "info"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "info" (car args))
                         (%get-taf-info-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-info (raw-args)
  (multiple-value-bind (mode scope query version-id json-p targets)
      (%parse-taf-info-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-info-help-string)))
      (:info
       (if (and targets
                (cdr targets))
           (taf.core:hub-info-many :scope scope
                                   :targets targets
                                   :json-p json-p)
           (taf.core:hub-info :scope scope
                              :query query
                              :version-id version-id
                              :json-p json-p)))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "info"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: install
;;;; ------------------------------------------------------------

(defun %get-taf-install-help-string-english ()
  "Usage:
  taf install [-h | --help]
  taf install [OPTIONS] <APP-NAME|TAF-COMMAND>...
  taf install [OPTIONS] <APP-NAME|TAF-COMMAND> <VERSION-ID>
  taf install [OPTIONS] --from <PROJECT-DIR>
  taf install [OPTIONS] --all
  taf install [OPTIONS] --all-installed --repair

Install a TAFFISH app from the local index or a local project.

Modes:
  indexed target       Install one or more apps/commands from index/current.json
  indexed exact        Install one app/command at an explicit VERSION-ID
  local project        Install a private project with --from <PROJECT-DIR>
  batch index          Plan or install all indexed apps selected by --kind
  installed repair     Repair existing versions with --all-installed --repair

Details:
  - accepts package names, for example my-tool
  - accepts command names, for example taf-my-tool
  - accepts exact versioned command names, for example taf-my-tool-v0.1.0-r1
  - defaults to the package latest version when VERSION-ID is omitted
  - installs dependencies declared by the selected version record first
  - installs the exact command, for example taf-my-tool-v0.1.0-r1
  - refreshes the unversioned command alias, for example taf-my-tool,
    to the latest installed local version
  - run `taf update` first if the local index is missing
  - --from searches upward for taffish.toml and records origin as
    [local-project] <PROJECT-ROOT>; it does not read the index
  - --all is dry-run by default; pass --yes to install
  - --all targets index latest; it does not automatically downgrade local apps
  - --prune-old requires a valid installed index latest and matching origins
  - --repair rebuilds only existing, verifiable indexed installations;
    it keeps backups, does not install missing apps/dependencies, and rejects
    --force, --from and --prune-old. Preview first with --dry-run
  - --all --repair checks installed index.latest targets only; other versions
    require an explicit version target or --all-installed --repair
  - --all-installed --repair previews all locally installed versions; --yes
    applies the plan. It never upgrades, installs missing versions or prunes
  - --all-installed cannot be combined with --all or explicit targets

Options:
  -u, --user                Install into user home [default]
  -s, --system              Install app data into system home and command
                            into TAFFISH_SYSTEM_BIN_DIR [/usr/local/bin]
  -n, --dry-run             Print install plan without changing files
  -y, --yes                 Apply a batch install/repair plan
  -f, --force               Replace an existing installation of this version
      --repair              Safely rebuild a verifiable existing installation
  -a, --all                 Install all indexed apps selected by --kind
      --all-installed       Select all installed versions; requires --repair
  -k, --kind <KIND>         Filter batch targets by tool, flow, or all [all]
      --tools               Shortcut for --kind tool
      --flows               Shortcut for --kind flow
      --prune-old           Safely prune older indexed versions after --all
  -j, --json                Print a batch plan/result as JSON
  --from <PROJECT-DIR>      Install from a local TAFFISH project directory
  --prompt                  Allow git to ask credentials through terminal
  -h, --help                Show this help

Examples:
  taf install fastqc
  taf install taf-fastqc-v0.12.1-r1
  taf install --from .
  taf install --all --tools --yes
  taf install --all --repair
  taf install --all --repair --yes
  taf install --all-installed --repair
  taf install --all-installed --repair --yes")

(defun %taf-install-targets-from-positionals (positionals)
  (%taf-hub-targets-from-positionals
   positionals
   "install"
   (%get-taf-install-help-string)))

(defun %parse-taf-install-args (raw-args)
  (let ((scope :user)
        (repair-p nil)
        (all-installed-p nil)
        (dry-run-p nil)
        (yes-p nil)
        (force-p nil)
        (prompt-p nil)
        (from-dir nil)
        (all-p nil)
        (kind :all)
        (json-p nil)
        (prune-old-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "install" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "install"
                                    :left "--user" :right "--system"))
                  (when (and dry-run-p yes-p)
                    (%taf-cli-error "conflict" :command "install"
                                    :left "--dry-run" :right "--yes"))
                  (when (and all-installed-p (not repair-p))
                    (%taf-cli-error "install-installed-requires-repair"))
                  (when (and all-installed-p (or all-p positionals))
                    (%taf-cli-error "install-installed-conflict"))
                  (when (and repair-p (or force-p from-dir prune-old-p))
                    (%taf-cli-error "conflict" :command "install" :left "--repair"
                                    :right (cond (force-p "--force") (from-dir "--from") (t "--prune-old"))))
                  (cond
                    (from-dir
                     (when (or positionals all-p json-p prune-old-p yes-p)
                       (%taf-cli-error-with-help
                        "install-from-conflict"
                        (%get-taf-install-help-string)))
                     (values :install-from-project
                             scope
                             nil
                             nil
                             dry-run-p
                             force-p
                             prompt-p
                             nil
                             from-dir
                             nil
                             kind
                             nil
                             nil
                             nil))
                    ((or all-p all-installed-p)
                     (when positionals
                       (%taf-cli-error-with-help
                        "install-all-targets"
                        (%get-taf-install-help-string)))
                     (values :install-all
                             scope
                             nil
                             nil
                             dry-run-p
                             force-p
                             prompt-p
                             nil
                             nil
                             all-p
                             kind
                             yes-p
                             json-p
                             prune-old-p
                             repair-p
                             all-installed-p))
                    (t
                     (when (or json-p prune-old-p yes-p)
                       (%taf-cli-error-with-help
                        "install-batch-only"
                        (%get-taf-install-help-string)))
                     (let* ((targets
                              (%taf-install-targets-from-positionals
                               positionals))
                            (first-target (first targets)))
                       (values :install
                               scope
                               (getf first-target :query)
                               (getf first-target :version-id)
                               dry-run-p
                               force-p
                               prompt-p
                               targets
                               nil
                               nil
                               kind
                               nil
                               nil
                               nil
                               repair-p)))))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil nil nil nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-n" "--dry-run")
                  (setf dry-run-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-y" "--yes")
                  (setf yes-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-f" "--force")
                  (setf force-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--repair")
                  (setf repair-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-a" "--all")
                  (setf all-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--all-installed")
                  (setf all-installed-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-k" "--kind")
                  (setf kind (%taf-hub-parse-kind
                              (require-value args "--kind")
                              "install"))
                  (parse (cddr args)))
                 ((string= (car args) "--tools")
                  (setf kind :tool)
                  (parse (cdr args)))
                 ((string= (car args) "--flows")
                  (setf kind :flow)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--prune-old")
                  (setf prune-old-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--prompt")
                  (setf prompt-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--from")
                  (when from-dir
                    (%taf-cli-error "install-from-once"))
                  (setf from-dir (require-value args "--from"))
                  (parse (cddr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-install-help-string)
                                            :command "install"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "install" (car args))
                         (%get-taf-install-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-install (raw-args)
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets from-dir
         all-p kind yes-p json-p prune-old-p repair-p all-installed-p)
      (%parse-taf-install-args raw-args)
    (declare (ignore all-p))
    (case mode
      (:help
       (format t "~A~%" (%get-taf-install-help-string)))
      (:install-from-project
       (taf.core:hub-install-from-project
        :start-dir from-dir
        :scope scope
        :dry-run-p dry-run-p
        :force-p force-p
        :prompt-p prompt-p))
      (:install
       (if (and targets
                (cdr targets))
           (taf.core:hub-install-many :scope scope
                                      :repair-p repair-p
                                      :targets targets
                                      :dry-run-p dry-run-p
                                      :force-p force-p
                                      :prompt-p prompt-p)
           (taf.core:hub-install :scope scope
                                 :repair-p repair-p
                                 :query query
                                 :version-id version-id
                                 :dry-run-p dry-run-p
                                 :force-p force-p
                                 :prompt-p prompt-p)))
      (:install-all
       (taf.core:hub-install-all :scope scope
                                 :repair-p repair-p
                                 :all-installed-p all-installed-p
                                 :kind kind
                                 :dry-run-p dry-run-p
                                 :yes-p yes-p
                                 :force-p force-p
                                 :prompt-p prompt-p
                                 :prune-old-p prune-old-p
                                 :json-p json-p))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "install"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: list
;;;; ------------------------------------------------------------

(defun %get-taf-list-help-string-english ()
  "Usage:
  taf list [-h | --help]
  taf list [-l | --local | -o | --online] [-u | --user | -s | --system]
           [-j | --json] [-n | --limit <N>]

List TAFFISH apps.

Details:
  - --local lists locally installed app versions from install metadata
  - --online lists indexed apps from index/current.json
  - defaults to --local and --user
  - --online reads the local index cache, so run `taf update` first
  - --limit limits the number of printed or JSON items

Options:
  -l, --local, --installed  List locally installed app versions [default]
  -o, --online, --index     List apps from local index cache
  -u, --user                Read user home [default]
  -s, --system              Read system home
  -j, --json                Print results as JSON
  -n, --limit <N>           Limit result count
  -h, --help                Show this help")

(defun %parse-taf-list-positive-integer (value option-name)
  (let ((n (and value
                (ignore-errors
                  (parse-integer value :junk-allowed nil)))))
    (unless (and n (> n 0))
      (%taf-cli-error "requires-positive-integer"
                      :command "list"
                      :option option-name
                      :value (%taf-cli-repr value)))
    n))

(defun %parse-taf-list-args (raw-args)
  (let ((scope :user)
        (list-mode :local)
        (json-p nil)
        (limit nil)
        (user-seen-p nil)
        (system-seen-p nil)
        (local-seen-p nil)
        (online-seen-p nil))
    (labels ((require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "list" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "list"
                                    :left "--user" :right "--system"))
                  (when (and local-seen-p online-seen-p)
                    (%taf-cli-error "conflict" :command "list"
                                    :left "--local" :right "--online"))
                  (values :list scope list-mode limit json-p))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil nil))
                 ((%taf-option-p (car args) "-l" "--local" "--installed")
                  (setf list-mode :local
                        local-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-o" "--online" "--index")
                  (setf list-mode :online
                        online-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-n" "--limit")
                  (setf limit
                        (%parse-taf-list-positive-integer
                         (require-value args "--limit")
                         "--limit"))
                  (parse (cddr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-or-argument-message
                          "list" (car args))
                         (%get-taf-list-help-string))))))
      (parse raw-args))))

(defun run-taf-list (raw-args)
  (multiple-value-bind (mode scope list-mode limit json-p)
      (%parse-taf-list-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-list-help-string)))
      (:list
       (taf.core:hub-list :mode list-mode
                          :scope scope
                          :limit limit
                          :json-p json-p))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "list"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: outdated
;;;; ------------------------------------------------------------

(defun %get-taf-outdated-help-string-english ()
  "Usage:
  taf outdated [-h | --help]
  taf outdated [-u | --user | -s | --system] [-a | --all] [-j | --json]
               [-k | --kind <tool|flow|all>] [APP-NAME|TAF-COMMAND...]

Show installed TAFFISH apps that are older than the local index.

Details:
  - reads local install metadata and index/current.json
  - with no target, checks all locally installed apps
  - default text shows changes and blocked maintenance; hides current items
  - prints no changes when there is nothing to change or explain
  - --json keeps current/skipped items for automation
  - local/private --from installs are shown as skipped, not upgraded
  - use taf upgrade to apply install-latest actions

Options:
  -u, --user                Check user home [default]
  -s, --system              Check system home
  -a, --all                 Explicitly check all installed apps [default]
  -k, --kind <KIND>         Filter by tool, flow, or all [all]
      --tools               Shortcut for --kind tool
      --flows               Shortcut for --kind flow
  -j, --json                Print result as JSON
  -h, --help                Show this help

Examples:
  taf outdated
  taf outdated --json
  taf outdated --tools taf-fastqc")

(defun %parse-taf-outdated-args (raw-args)
  (let ((scope :user)
        (kind :all)
        (json-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil)
        (all-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "outdated" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "outdated"
                                    :left "--user" :right "--system"))
                  (when (and all-seen-p positionals)
                    (%taf-cli-error-with-help
                     "all-explicit-targets"
                     (%get-taf-outdated-help-string)
                     :command "outdated"))
                  (values :outdated
                          scope
                          kind
                          json-p
                          (%taf-hub-targets-from-optional-positionals
                           positionals
                           "outdated"
                           (%get-taf-outdated-help-string))))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-a" "--all")
                  (setf all-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-k" "--kind")
                  (setf kind (%taf-hub-parse-kind
                              (require-value args "--kind")
                              "outdated"))
                  (parse (cddr args)))
                 ((string= (car args) "--tools")
                  (setf kind :tool)
                  (parse (cdr args)))
                 ((string= (car args) "--flows")
                  (setf kind :flow)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-outdated-help-string)
                                            :command "outdated"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "outdated" (car args))
                         (%get-taf-outdated-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-outdated (raw-args)
  (multiple-value-bind (mode scope kind json-p targets)
      (%parse-taf-outdated-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-outdated-help-string)))
      (:outdated
       (taf.core:hub-outdated :scope scope
                              :kind kind
                              :json-p json-p
                              :targets targets))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "outdated"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: upgrade
;;;; ------------------------------------------------------------

(defun %get-taf-upgrade-help-string-english ()
  "Usage:
  taf upgrade [-h | --help]
  taf upgrade [-u | --user | -s | --system] [-n | --dry-run | -y | --yes]
              [-a | --all] [-k | --kind <tool|flow|all>] [-f | --force]
              [--prompt] [--prune-old] [-j | --json]
              [APP-NAME|TAF-COMMAND...]

Install newer indexed versions for locally installed TAFFISH apps.

Details:
  - with no target, checks all locally installed apps
  - dry-run is the default; pass --yes to apply the plan
  - default text shows changes/blockers; otherwise prints no changes
  - --json keeps current/skipped items for automation
  - local/private --from installs are skipped
  - --prune-old removes older local versions after successful upgrades
  - index latest is the target; newer local/private versions are not downgraded

Options:
  -u, --user                Upgrade user home [default]
  -s, --system              Upgrade system home
  -n, --dry-run             Print upgrade plan without changing files [default]
  -y, --yes                 Apply the upgrade plan
  -f, --force               Replace existing install paths if needed
  -a, --all                 Explicitly upgrade all installed apps [default]
  -k, --kind <KIND>         Filter by tool, flow, or all [all]
      --tools               Shortcut for --kind tool
      --flows               Shortcut for --kind flow
      --prune-old           Safely prune older indexed versions after upgrade
      --prompt              Allow git to ask credentials through terminal
  -j, --json                Print result as JSON
  -h, --help                Show this help

Examples:
  taf upgrade
  taf upgrade --yes
  taf upgrade taf-fastqc --yes --prune-old")

(defun %parse-taf-upgrade-args (raw-args)
  (let ((scope :user)
        (dry-run-p nil)
        (yes-p nil)
        (force-p nil)
        (prompt-p nil)
        (kind :all)
        (json-p nil)
        (prune-old-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil)
        (all-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "upgrade" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "upgrade"
                                    :left "--user" :right "--system"))
                  (when (and dry-run-p yes-p)
                    (%taf-cli-error "conflict" :command "upgrade"
                                    :left "--dry-run" :right "--yes"))
                  (when (and all-seen-p positionals)
                    (%taf-cli-error-with-help
                     "all-explicit-targets"
                     (%get-taf-upgrade-help-string)
                     :command "upgrade"))
                  (values :upgrade
                          scope
                          kind
                          dry-run-p
                          yes-p
                          force-p
                          prompt-p
                          prune-old-p
                          json-p
                          (%taf-hub-targets-from-optional-positionals
                           positionals
                           "upgrade"
                           (%get-taf-upgrade-help-string))))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-n" "--dry-run")
                  (setf dry-run-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-y" "--yes")
                  (setf yes-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-f" "--force")
                  (setf force-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-a" "--all")
                  (setf all-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-k" "--kind")
                  (setf kind (%taf-hub-parse-kind
                              (require-value args "--kind")
                              "upgrade"))
                  (parse (cddr args)))
                 ((string= (car args) "--tools")
                  (setf kind :tool)
                  (parse (cdr args)))
                 ((string= (car args) "--flows")
                  (setf kind :flow)
                  (parse (cdr args)))
                 ((string= (car args) "--prompt")
                  (setf prompt-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--prune-old")
                  (setf prune-old-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-upgrade-help-string)
                                            :command "upgrade"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "upgrade" (car args))
                         (%get-taf-upgrade-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-upgrade (raw-args)
  (multiple-value-bind
        (mode scope kind dry-run-p yes-p force-p prompt-p prune-old-p json-p targets)
      (%parse-taf-upgrade-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-upgrade-help-string)))
      (:upgrade
       (taf.core:hub-upgrade :scope scope
                             :kind kind
                             :dry-run-p dry-run-p
                             :yes-p yes-p
                             :force-p force-p
                             :prompt-p prompt-p
                             :prune-old-p prune-old-p
                             :json-p json-p
                             :targets targets))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "upgrade"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: prune
;;;; ------------------------------------------------------------

(defun %get-taf-prune-help-string-english ()
  "Usage:
  taf prune [-h | --help]
  taf prune [-u | --user | -s | --system] [-n | --dry-run | -y | --yes]
            [-a | --all] [-k | --kind <tool|flow|all>] [-j | --json]
            [APP-NAME|TAF-COMMAND...]

Remove older locally installed TAFFISH app versions.

Details:
  - with no target, checks all locally installed apps
  - retains the valid, same-source installed version named by index latest
  - skips apps without a usable index latest or a valid installed target
  - protects private, unknown-source, newer and unorderable local versions
  - dry-run is the default; pass --yes to delete old versions
  - text shows removable versions and blocked maintenance; JSON keeps all items
  - prints no changes when there is nothing to remove or explain
  - keeps shared container images and SIF files

Options:
  -u, --user                Prune user home [default]
  -s, --system              Prune system home
  -n, --dry-run             Print prune plan without deleting [default]
  -y, --yes                 Apply the prune plan
  -a, --all                 Explicitly prune all installed apps [default]
  -k, --kind <KIND>         Filter by tool, flow, or all [all]
      --tools               Shortcut for --kind tool
      --flows               Shortcut for --kind flow
  -j, --json                Print result as JSON
  -h, --help                Show this help

Examples:
  taf prune
  taf prune --yes
  taf prune --kind flow --yes")

(defun %parse-taf-prune-args (raw-args)
  (let ((scope :user)
        (dry-run-p nil)
        (yes-p nil)
        (kind :all)
        (json-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil)
        (all-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (%taf-cli-error "requires-value"
                                   :command "prune" :option option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "prune"
                                    :left "--user" :right "--system"))
                  (when (and dry-run-p yes-p)
                    (%taf-cli-error "conflict" :command "prune"
                                    :left "--dry-run" :right "--yes"))
                  (when (and all-seen-p positionals)
                    (%taf-cli-error-with-help
                     "all-explicit-targets"
                     (%get-taf-prune-help-string)
                     :command "prune"))
                  (values :prune
                          scope
                          kind
                          dry-run-p
                          yes-p
                          json-p
                          (%taf-hub-targets-from-optional-positionals
                           positionals
                           "prune"
                           (%get-taf-prune-help-string))))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-n" "--dry-run")
                  (setf dry-run-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-y" "--yes")
                  (setf yes-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-a" "--all")
                  (setf all-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-k" "--kind")
                  (setf kind (%taf-hub-parse-kind
                              (require-value args "--kind")
                              "prune"))
                  (parse (cddr args)))
                 ((string= (car args) "--tools")
                  (setf kind :tool)
                  (parse (cdr args)))
                 ((string= (car args) "--flows")
                  (setf kind :flow)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-prune-help-string)
                                            :command "prune"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "prune" (car args))
                         (%get-taf-prune-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-prune (raw-args)
  (multiple-value-bind (mode scope kind dry-run-p yes-p json-p targets)
      (%parse-taf-prune-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-prune-help-string)))
      (:prune
       (taf.core:hub-prune :scope scope
                           :kind kind
                           :dry-run-p dry-run-p
                           :yes-p yes-p
                           :json-p json-p
                           :targets targets))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "prune"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: uninstall
;;;; ------------------------------------------------------------

(defun %get-taf-uninstall-help-string-english ()
  "Usage:
  taf uninstall [-h | --help]
  taf uninstall [-u | --user | -s | --system] [-n | --dry-run]
                [-f | --force]
                <APP-NAME|TAF-COMMAND>...
  taf uninstall [-u | --user | -s | --system] [-n | --dry-run]
                [-f | --force]
                <APP-NAME|TAF-COMMAND> <VERSION-ID>

Uninstall a TAFFISH app from the local TAFFISH home.

Details:
  - reads local install metadata, not the online index
  - accepts package names, for example my-tool
  - accepts command names, for example taf-my-tool
  - accepts exact versioned command names, for example taf-my-tool-v0.1.0-r1
  - accepts multiple app/command targets in one command
  - removes apps/<APP-NAME>/<VERSION-ID>/ and the exact command launcher
  - refreshes the unversioned command alias to the remaining local latest
    version, or removes it when no version remains
  - keeps shared container images and SIF files
  - when VERSION-ID is omitted, exactly one installed version must match
  - for batch exact versions, prefer exact versioned command names

Options:
  -u, --user                Uninstall from user home [default]
  -s, --system              Uninstall from system home
  -n, --dry-run             Print uninstall plan without changing files
  -f, --force               Do not fail when the app is not installed
  -h, --help                Show this help")

(defun %parse-taf-uninstall-args (raw-args)
  (let ((scope :user)
        (dry-run-p nil)
        (force-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (parse (args)
               (cond
                ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "uninstall"
                                    :left "--user" :right "--system"))
                  (let* ((targets
                           (%taf-hub-targets-from-positionals
                            positionals
                            "uninstall"
                            (%get-taf-uninstall-help-string)))
                         (first-target (first targets)))
                    (values :uninstall
                            scope
                            (getf first-target :query)
                            (getf first-target :version-id)
                            dry-run-p
                            force-p
                            targets)))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-n" "--dry-run")
                  (setf dry-run-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-f" "--force")
                  (setf force-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-uninstall-help-string)
                                            :command "uninstall"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "uninstall" (car args))
                         (%get-taf-uninstall-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-uninstall (raw-args)
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p targets)
      (%parse-taf-uninstall-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-uninstall-help-string)))
      (:uninstall
       (if (and targets
                (cdr targets))
           (taf.core:hub-uninstall-many :scope scope
                                        :targets targets
                                        :dry-run-p dry-run-p
                                        :force-p force-p)
           (taf.core:hub-uninstall :scope scope
                                   :query query
                                   :version-id version-id
                                   :dry-run-p dry-run-p
                                   :force-p force-p)))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "uninstall"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: hub: which
;;;; ------------------------------------------------------------

(defun %get-taf-which-help-string-english ()
  "Usage:
  taf which [-h | --help]
  taf which [-u | --user | -s | --system] [-j | --json]
            <APP-NAME|TAF-COMMAND>...
  taf which [-u | --user | -s | --system] [-j | --json]
            <APP-NAME|TAF-COMMAND> <VERSION-ID>

Show local installation path and metadata for a TAFFISH command.

Details:
  - reads local install metadata, not the online index
  - accepts package names, for example my-tool
  - accepts command names, for example taf-my-tool
  - accepts exact versioned command names, for example taf-my-tool-v0.1.0-r1
  - accepts multiple app/command targets in one command
  - shows launcher, frozen command file, source snapshot and install metadata
  - when VERSION-ID is omitted, exactly one installed version must match
  - for batch exact versions, prefer exact versioned command names
  - --json prints one object for one target and an array for multiple targets

Options:
  -u, --user                Search user home [default]
  -s, --system              Search system home
  -j, --json                Print result as JSON
  -h, --help                Show this help")

(defun %parse-taf-which-args (raw-args)
  (let ((scope :user)
        (json-p nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (parse (args)
               (cond
                ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "which"
                                    :left "--user" :right "--system"))
                  (let* ((targets
                           (%taf-hub-targets-from-positionals
                            positionals
                            "which"
                            (%get-taf-which-help-string)))
                         (first-target (first targets)))
                    (values :which
                            scope
                            (getf first-target :query)
                            (getf first-target :version-id)
                            json-p
                            targets)))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (%taf-cli-error-with-help "help-alone"
                                            (%get-taf-which-help-string)
                                            :command "which"))
                 ((option-like-p (car args))
                  (error "~A~%~A"
                         (%taf-unknown-option-message "which" (car args))
                         (%get-taf-which-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-which (raw-args)
  (multiple-value-bind (mode scope query version-id json-p targets)
      (%parse-taf-which-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-which-help-string)))
      (:which
       (if (and targets
                (cdr targets))
           (taf.core:hub-which-many :scope scope
                                    :targets targets
                                    :json-p json-p)
           (taf.core:hub-which :scope scope
                               :query query
                               :version-id version-id
                               :json-p json-p)))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "which"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: doctor
;;;; ------------------------------------------------------------

(defun %get-taf-doctor-help-string-english ()
  "Usage:
  taf doctor [-h | --help]
  taf doctor [-u | --user | -s | --system] [--shell SHELL]
  taf doctor [-i | --init] [-u | --user | -s | --system]
  taf doctor [-j | --json | --verbose] [--shell SHELL]
  taf doctor index [-u | --user | -s | --system] [-j | --json | --verbose]
  taf doctor hub [APP|COMMAND...] [-u | --user | -s | --system] [-j | --json | --verbose]

Check or initialize the local TAFFISH environment.

Details:
  - resolves TAFFISH_USER_HOME, TAFFISH_SYSTEM_HOME and TAFFISH_SYSTEM_BIN_DIR
  - checks home/config/index, PATH, completion, Vim, SIF cache and backends
  - uses bounded probes for docker, podman and apptainer without running apps
  - reports mksquashfs, squashfuse, fuse2fs and gocryptfs availability
  - does not edit shell/Vim config, permissions, services or container state
  - --init creates missing directories for the selected scope
  - --system --init requires root permission
  - index checks local JSON/schema/latest references; hub also checks installed files
  - hub accepts app names or versioned commands; no targets means all installed versions
  - output separates enumerated totals from affected apps/versions and issue counts
  - concise output groups repeated issues; --verbose/--json preserve all evidence
  - hub shows progress on stderr in text mode; JSON and MCP remain quiet
  - index/hub are offline, read-only and do not accept --init or --shell
  - missing old manifests are unverified, not proof of damage; no automatic repair
  - preview repairs including old versions: taf install --all-installed --repair
    add --user or --system to match the diagnosed scope
  - index/hub exit 1 for blocking problems, 0 for success or warnings only

Options:
  -i, --init                Create missing TAFFISH home directories
  -u, --user                Check or initialize user home [default]
  -s, --system              Check or initialize system home
  -j, --json                Print stable JSON diagnostics
  --verbose                 Print evidence and remediation for every check
  --shell SHELL             Inspect auto|bash|zsh|fish [default: auto]
  -h, --help                Show this help")

(defun %parse-taf-doctor-args (raw-args)
  (let ((init-p nil)
        (scope :user)
        (scope-seen-p nil)
        (user-seen-p nil)
        (system-seen-p nil)
        (json-p nil)
        (verbose-p nil)
        (check :environment)
        (targets nil)
        (shell-seen-p nil)
        (shell :auto))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "doctor"
                                    :left "--user" :right "--system"))
                  (when (and json-p verbose-p)
                    (%taf-cli-error "conflict" :command "doctor"
                                    :left "--json" :right "--verbose"))
                  (when (and (not (eql check :environment)) (or init-p shell-seen-p))
                    (taf.core::%doctor-error "check-options"))
                  (values :doctor init-p scope scope-seen-p
                          json-p verbose-p shell check (nreverse targets)))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil nil nil nil))
                 ((%taf-option-p (car args) "-i" "--init")
                  (setf init-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        scope-seen-p t
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        scope-seen-p t
                        system-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-j" "--json")
                  (setf json-p t)
                  (parse (cdr args)))
                 ((string-equal (car args) "--verbose")
                  (setf verbose-p t)
                  (parse (cdr args)))
                 ((string-equal (car args) "--shell")
                  (setf shell-seen-p t)
                  (unless (cdr args)
                    (%taf-cli-error "doctor-shell-required"))
                  (let ((value (second args)))
                    (unless (member value '("auto" "bash" "zsh" "fish")
                                    :test #'string-equal)
                      (%taf-cli-error "doctor-shell-invalid"
                                      :value (%taf-cli-repr value)))
                    (setf shell (intern (string-upcase value) :keyword)))
                  (parse (cddr args)))
                 ((and (eql check :environment)
                       (member (car args) '("index" "hub") :test #'string=))
                  (setf check (if (string= (car args) "index") :index :hub))
                  (parse (cdr args)))
                 ((and (eql check :hub) (plusp (length (car args)))
                       (not (char= (char (car args) 0) #\-)))
                  (push (car args) targets)
                  (parse (cdr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-message "doctor" (car args))
                         (%get-taf-doctor-help-string))))))
      (parse raw-args))))

(defun run-taf-doctor (raw-args)
  (multiple-value-bind (mode init-p scope scope-seen-p json-p verbose-p shell check targets)
      (%parse-taf-doctor-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-doctor-help-string)))
      (:doctor
       (when (and init-p
                  (not scope-seen-p)
                  (taf.core::%root-user-p))
         (%taf-cli-error "doctor-root-ambiguous"))
       (taf.core:system-doctor :init-p init-p
                               :check check :targets targets
                               :scope scope
                               :shell shell
                               :detail-p verbose-p
                               :json-p json-p))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "doctor"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: config
;;;; ------------------------------------------------------------

(defun %get-taf-config-help-string-english ()
  "Usage:
  taf config [-h | --help]
  taf config [show] [-u | --user | -s | --system]
  taf config path [-u | --user | -s | --system]
  taf config init [-u | --user | -s | --system]
                  [--github | --china] [-f | --force]
  taf config language [--show] [-u | --user | -s | --system]
  taf config language <LANGUAGE> [-u | --user | -s | --system]

Show, initialize, or manage TAFFISH runtime configuration.

Details:
  - reads TAFFISH_USER_HOME and TAFFISH_SYSTEM_HOME when set
  - falls back to ~/.local/share/taffish and /opt/taffish
  - reads config.toml from the selected TAFFISH home when present
  - reads TAFFISH_CONFIG as an explicit config file override when set
  - config controls index URL and source URL rewrite for installation
  - language lists built-in and valid external languages, or saves one choice
  - en and zh are built in; auto is the default and follows the host locale
  - unrecognized or missing host locale data falls back to English
  - TAFFISH_LANGUAGE temporarily overrides the saved language
  - prints the active apps/index/images/bin/cache/share/logs paths
  - show/path do not check, create or repair directories

Options:
  -u, --user                Show user home as active scope [default]
  -s, --system              Show system home as active scope
  --github                  Initialize GitHub/default profile
  --china                   Initialize China mirror profile template
  --show                    Show language configuration and available languages
  -f, --force               Replace existing config file during init
  -h, --help                Show this help

Examples:
  taf config language
  taf config language zh
  taf config language auto
  taf config init --china")

(defun %parse-taf-config-args (raw-args)
  (let ((scope :user)
        (mode :config)
        (profile :github)
        (force-p nil)
        (language nil)
        (language-show-p nil)
        (mode-seen-p nil)
        (profile-seen-p nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (%taf-cli-error "conflict" :command "config"
                                    :left "--user" :right "--system"))
                  (when (and language-show-p (not (eql mode :language)))
                    (%taf-cli-error "config-show-language-only"))
                  (when (and language-show-p language)
                    (%taf-cli-error "config-show-value-conflict"))
                  (when (and (eql mode :language)
                             (or profile-seen-p force-p))
                    (%taf-cli-error "config-language-options"))
                  (values mode scope profile force-p language))
                 ((member (car args) '("-h" "--help") :test #'string-equal)
                  (values :help nil nil nil))
                 ((member (car args) '("show" "path" "init" "language")
                          :test #'string-equal)
                  (when mode-seen-p
                    (%taf-cli-error "config-one-subcommand"))
                  (setf mode (cond
                               ((string-equal (car args) "show") :config)
                               ((string-equal (car args) "path") :path)
                               ((string-equal (car args) "language") :language)
                               (t :init))
                        mode-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-u" "--user")
                  (setf scope :user
                        user-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-s" "--system")
                  (setf scope :system
                        system-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--github")
                  (when profile-seen-p
                    (%taf-cli-error "conflict" :command "config"
                                    :left "--github" :right "--china"))
                  (setf profile :github
                        profile-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--china")
                  (when profile-seen-p
                    (%taf-cli-error "conflict" :command "config"
                                    :left "--github" :right "--china"))
                  (setf profile :china
                        profile-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--show")
                  (setf language-show-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-f" "--force")
                  (setf force-p t)
                  (parse (cdr args)))
                 ((and (eql mode :language)
                       (not language)
                       (not language-show-p)
                       (not (and (> (length (car args)) 0)
                                 (char= #\- (char (car args) 0)))))
                  (setf language (car args))
                  (parse (cdr args)))
                 (t
                  (error "~A~%~A"
                         (%taf-unknown-option-message "config" (car args))
                         (%get-taf-config-help-string))))))
      (parse raw-args))))

(defun run-taf-config (raw-args)
  (multiple-value-bind (mode scope profile force-p language)
      (%parse-taf-config-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-config-help-string)))
      (:config
       (taf.core:system-config :scope scope))
      (:path
       (taf.core:system-config-path :scope scope))
      (:init
       (taf.core:system-config-init :scope scope
                                    :profile profile
                                    :force-p force-p))
      (:language
       (taf.core:system-config-language :scope scope :language language))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "config"
                       :mode (%taf-cli-repr mode))))))

;;;; ------------------------------------------------------------
;;;; run: history
;;;; ------------------------------------------------------------

(defun %get-taf-history-help-string-english ()
  "Usage:
  taf history [-h | --help]
  taf history [-l | --last <N>] [-j | --json]
  taf history [-i | --id <RUN-ID>] [-j | --json]
  taf history [-p | --path]
  taf history [-c | --clear]

Show local TAFFISH execution history and provenance.

Details:
  - reads $TAFFISH_USER_HOME/logs/history.jsonl
  - records taf run, taf build, generated command exec,
    and successful taf publish events
  - defaults to showing the last 20 events
  - does not record config/doctor/system-only commands

Options:
  -l, --last <N>            Show last N events, default 20
  -i, --id <RUN-ID>         Show one event by history id
  -j, --json                Print raw JSONL records
  -p, --path                Print history file path
  -c, --clear               Clear history file
  -h, --help                Show this help")

(defun %parse-taf-history-positive-integer (value option-name)
  (let ((n (and value
                (ignore-errors
                  (parse-integer value :junk-allowed nil)))))
    (unless (and n (> n 0))
      (%taf-cli-error "requires-positive-integer"
                      :command "history"
                      :option option-name
                      :value (%taf-cli-repr value)))
    n))

(defun %parse-taf-history-nonnegative-integer (value option-name)
  (let ((n (and value
                (ignore-errors
                  (parse-integer value :junk-allowed nil)))))
    (unless (and n (>= n 0))
      (%taf-cli-error "requires-non-negative-integer"
                      :command "history"
                      :option option-name
                      :value (%taf-cli-repr value)))
    n))

(defun %taf-history-empty-string-to-nil (value)
  (if (and (stringp value)
           (string= value ""))
      nil
      value))

(defun %parse-taf-history-record-exec-args (raw-args)
  (let ((status nil)
        (command nil)
        (project-name nil)
        (project-kind nil)
        (project-version nil)
        (project-release nil)
        (project-command nil)
        (project-root nil)
        (project-main nil)
        (repository-url nil)
        (container-image nil)
        (snapshot-root nil)
        (cwd nil)
        (stage nil)
        (exit-code nil)
        (app-args nil))
    (labels ((require-value (args option)
               (unless (cadr args)
                 (%taf-cli-error "requires-value"
                                 :command "history" :option option))
               (cadr args))
             (parse (args)
               (cond
                 ((null args)
                  (unless status
                    (%taf-cli-error "history-record-requires"
                                    :option "--status"))
                  (unless command
                    (%taf-cli-error "history-record-requires"
                                    :option "--command"))
                  (unless exit-code
                    (%taf-cli-error "history-record-requires"
                                    :option "--exit-code"))
                  (values
                   :record-exec
                   (list :event "exec"
                         :status status
                         :command command
                         :args app-args
                         :cwd cwd
                         :exit-code exit-code
                         :project
                         (list :name project-name
                               :kind project-kind
                               :version project-version
                               :release project-release
                               :command-name project-command
                               :root-dir project-root
                               :main-path project-main
                               :repository-url repository-url
                               :container-image container-image)
                         :extra
                         (list :stage stage
                               :snapshot-root snapshot-root))
                   nil nil nil nil))
                 ((string= (car args) "--")
                  (setf app-args (cdr args))
                  (parse nil))
                 ((string= (car args) "--status")
                  (setf status (require-value args "--status"))
                  (parse (cddr args)))
                 ((string= (car args) "--command")
                  (setf command (require-value args "--command"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-name")
                  (setf project-name (require-value args "--project-name"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-kind")
                  (setf project-kind (require-value args "--project-kind"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-version")
                  (setf project-version (require-value args "--project-version"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-release")
                  (setf project-release (require-value args "--project-release"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-command")
                  (setf project-command (require-value args "--project-command"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-root")
                  (setf project-root (require-value args "--project-root"))
                  (parse (cddr args)))
                 ((string= (car args) "--project-main")
                  (setf project-main (require-value args "--project-main"))
                  (parse (cddr args)))
                 ((string= (car args) "--repository-url")
                  (setf repository-url
                        (%taf-history-empty-string-to-nil
                         (require-value args "--repository-url")))
                  (parse (cddr args)))
                 ((string= (car args) "--container-image")
                  (setf container-image
                        (%taf-history-empty-string-to-nil
                         (require-value args "--container-image")))
                  (parse (cddr args)))
                 ((string= (car args) "--snapshot-root")
                  (setf snapshot-root (require-value args "--snapshot-root"))
                  (parse (cddr args)))
                 ((string= (car args) "--cwd")
                  (setf cwd (require-value args "--cwd"))
                  (parse (cddr args)))
                 ((string= (car args) "--stage")
                  (setf stage (require-value args "--stage"))
                  (parse (cddr args)))
                 ((string= (car args) "--exit-code")
                  (setf exit-code
                        (%parse-taf-history-nonnegative-integer
                         (require-value args "--exit-code")
                         "--exit-code"))
                  (parse (cddr args)))
                 (t
                  (%taf-cli-error "history-record-option"
                                  :option (%taf-cli-repr (car args)))))))
      (parse raw-args))))

(defun %parse-taf-history-args (raw-args)
  (if (and raw-args
           (string= (car raw-args) "--record-exec"))
      (%parse-taf-history-record-exec-args (cdr raw-args))
      (let ((last 20)
            (id nil)
            (json-p nil)
            (path-p nil)
            (clear-p nil)
            (path-seen-p nil)
            (clear-seen-p nil))
        (labels ((parse (args)
                   (cond
                     ((null args)
                      (when (and path-seen-p clear-seen-p)
                        (%taf-cli-error "conflict" :command "history"
                                        :left "--path" :right "--clear"))
                      (when (and (or path-p clear-p)
                                 (or id json-p (not (= last 20))))
                        (%taf-cli-error "history-path-clear-query"))
                      (values :history last id json-p path-p clear-p))
                     ((and (null (cdr args))
                           (member (car args) '("-h" "--help") :test #'string-equal))
                      (values :help nil nil nil nil nil))
                     ((%taf-option-p (car args) "-l" "--last")
                      (unless (cadr args)
                        (%taf-cli-error "history-last-value"))
                      (setf last (%parse-taf-history-positive-integer
                                  (cadr args) "--last"))
                      (parse (cddr args)))
                     ((%taf-option-p (car args) "-i" "--id")
                      (unless (cadr args)
                        (%taf-cli-error "history-id-value"))
                      (setf id (cadr args))
                      (parse (cddr args)))
                     ((%taf-option-p (car args) "-j" "--json")
                      (setf json-p t)
                      (parse (cdr args)))
                     ((%taf-option-p (car args) "-p" "--path")
                      (setf path-p t
                            path-seen-p t)
                      (parse (cdr args)))
                     ((%taf-option-p (car args) "-c" "--clear")
                      (setf clear-p t
                            clear-seen-p t)
                      (parse (cdr args)))
                     (t
                      (error "~A~%~A"
                             (%taf-unknown-option-message
                              "history" (car args))
                             (%get-taf-history-help-string))))))
          (parse raw-args)))))

(defun run-taf-history (raw-args)
  (multiple-value-bind (mode last id json-p path-p clear-p)
      (%parse-taf-history-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-history-help-string)))
      (:history
       (taf.core:system-history :last last
                                :id id
                                :json-p json-p
                                :path-p path-p
                                :clear-p clear-p))
      (:record-exec
       (apply #'%record-taf-history-event last))
      (t
       (%taf-cli-error "unknown-mode"
                       :command "history"
                       :mode (%taf-cli-repr mode))))))
