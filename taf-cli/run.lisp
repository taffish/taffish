(in-package :taf.cli)

;;;; ============================================================
;;;; run.lisp
;;;; ============================================================

;;;; ------------------------------------------------------------
;;;; run: version
;;;; ------------------------------------------------------------

(defparameter *taf-version*
  "taf 0.8.1 (2026-05, Kaiyuan Han)")

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

(defun %get-taf-help-string ()
  "Usage:
  taf [-h | --help | help]
  taf [-v | --version | version]
  taf <COMMAND> [-h | --help]
  taf <COMMAND> [ARGS...]

Project commands:
  new <APP-NAME>                  Create a new TAFFISH app project
  check                           Check current TAFFISH app project
  compile                         Compile current project and print shell code
  build [OPTIONS]                 Build current project into taf-command
  run [OPTIONS] [ARGS...]         Compile and run current project
  publish [OPTIONS]               Publish current project to GitHub

Hub commands:
  update [OPTIONS]                Update local TAFFISH index
  search [OPTIONS] <KEYWORD>      Search apps from local index
  info [OPTIONS] <APP|COMMAND>... Show indexed app/version information
  install [OPTIONS] <APP|COMMAND>...
                                  Install apps or commands from local index
  uninstall [OPTIONS] <APP|COMMAND>...
                                  Uninstall local apps or commands
  list [OPTIONS]                  List installed or indexed apps
  which [OPTIONS] <APP|COMMAND>...
                                  Show local paths and metadata

System commands:
  doctor [OPTIONS]
                                  Check or initialize TAFFISH environment
  config [OPTIONS]                Show TAFFISH config
  history [OPTIONS]               Show or clear local run history")

(defun run-taf-help ()
  (format t "~A~%" *taf-version*)
  (%format-split-line *taf-version* #\-)
  (format t "~A~%" (%get-taf-help-string)))

;;;; ------------------------------------------------------------
;;;; run: project: new
;;;; ------------------------------------------------------------

(defun %get-taf-new-help-string ()
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
       (error "[new] project name missing.~%~A"
              (%get-taf-new-help-string)))
      ((member name '("-h" "--help") :test #'string-equal)
       (format t "~A~%" (%get-taf-new-help-string)))
      (t
       (taf.core:project-new name args)))))

;;;; ------------------------------------------------------------
;;;; run: project: check
;;;; ------------------------------------------------------------

(defun %get-taf-check-help-string ()
  "Usage:
  taf check [-h | --help]
  taf check

Check the current TAFFISH app project.

Details:
  - finds taffish.toml from current directory upward
  - checks required files
  - checks basic taffish.toml fields
  - parses the main .taf file
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
     (error "[check] taf check does not accept arguments.~%~A"
            (%get-taf-check-help-string)))))

;;;; ------------------------------------------------------------
;;;; run: project: compile
;;;; ------------------------------------------------------------

(defun %get-taf-compile-help-string ()
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
       (error "[compile] unknown compile mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: project: build
;;;; ------------------------------------------------------------

(defun %get-taf-build-help-string ()
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
                    (error "[build] --backend requires docker or podman."))
                  (setf backend (cadr args))
                  (parse (cddr args)))
                 (t
                  (error "[build] unknown option: ~S~%~A"
                         (car args)
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
       (error "[build] unknown build mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: project: run
;;;; ------------------------------------------------------------

(defun %get-taf-run-help-string ()
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

Options:
  -b, --backend <docker|podman|apptainer>
                            Force generic <container:...> tags to use backend
  -h, --help                Show this help

Note:
  Use `--` before ARGS when the .taf program needs option-like arguments,
  for example `taf run -- -h` or `taf run -- --backend value`.")

(defun %standard-input-terminal-p ()
  (interactive-stream-p *standard-input*))

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
                    (error "[run] --backend requires apptainer, podman or docker."))
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
       (error "[run] unknown run mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: project: publish
;;;; ------------------------------------------------------------

(defun %get-taf-publish-help-string ()
  "Usage:
  taf publish [-h | --help]
  taf publish [-n | --dry-run] [--latest | --pre] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]
  taf publish [-y | --yes] [--latest | --pre] [-b | --build]
              [-r | --release] [--create-repo] [--public | --private]
              [--no-lock-repo] [--prompt]

Publish the current TAFFISH app project to its GitHub repository.

Details:
  - runs taf check first
  - reads [repository].url from taffish.toml
  - checks remote tags named v<version>-r<release>
  - remote git checks are non-interactive unless --prompt is given
  - with --release, reads release.md and creates a GitHub release
  - can create the GitHub repository when --create-repo is given
  - newly created repositories are locked by default:
    immutable releases are enabled and v* tags are protected from update/delete
  - rejects already-published tags
  - commits, tags, pushes and optional release creation only when --yes is given

Options:
  -n, --dry-run              Print publish plan only [default]
  -y, --yes                  Run publish actions: commit, tag, push and release
  -b, --build                Build command wrapper before publishing
  -r, --release              Read release.md from project root:
                              first line becomes publish message;
                              whole file becomes GitHub release notes
  --latest                   Require a version newer than remote latest [default]
  --pre                      Allow publishing a non-latest pre-release tag
  --create-repo              Create GitHub repository if it is missing
  --public                   Create missing repository as public [default]
  --private                  Create missing repository as private
  --no-lock-repo             Do not lock a newly created repository
  --prompt                   Allow git to ask credentials through terminal
  -h, --help                 Show this help

Note:
  TAF does not manage GitHub login. Without --prompt, remote git commands
  fail fast instead of asking for credentials.")

(defun %parse-taf-publish-args (raw-args)
  (let ((dry-run t)
        (build-p nil)
        (channel :latest)
        (dry-run-seen-p nil)
        (yes-seen-p nil)
        (latest-seen-p nil)
        (pre-seen-p nil)
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
                    (error "[publish] --dry-run and --yes can't be used together."))
                  (when (and latest-seen-p pre-seen-p)
                    (error "[publish] --latest and --pre can't be used together."))
                  (when (and public-seen-p private-seen-p)
                    (error "[publish] --public and --private can't be used together."))
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
                  (error "[publish] unknown option: ~S~%~A"
                         (car args)
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
       (let ((result
               (taf.core:project-publish :dry-run dry-run
                                         :build-p build-p
                                         :channel channel
                                         :prompt-p prompt-p
                                         :create-repo-p create-repo-p
                                         :repo-visibility repo-visibility
                                         :lock-repo-p lock-repo-p
                                         :release-p release-p)))
         (when (getf result :published-p)
           (%record-taf-history-event
            :event "publish"
            :status "success"
            :project (getf result :project)
            :cwd (han.os:current-directory)
            :extra (list :tag (getf result :tag)
                         :channel (getf result :channel)
                         :repository-url (getf result :repository-url)
                         :build (not (null (getf result :build)))
                         :release (not (null (getf result :release)))
                         :created-repo
                         (not (null (getf (getf result :execute)
                                          :created-repo))))))
         result))
      (t
       (error "[publish] unknown publish mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: update
;;;; ------------------------------------------------------------

(defun %get-taf-update-help-string ()
  "Usage:
  taf update [-h | --help]
  taf update [-u | --user | -s | --system] [--url <INDEX-URL>] [-y | --yes]

Update the local TAFFISH index cache.

Details:
  - downloads a static TAFFISH index JSON file
  - writes index/current.json for the selected scope
  - writes a timestamped copy under index/snapshots/
  - reads TAFFISH_INDEX_URL when --url is not given
  - defaults to the official taffish index

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
                   (error "[update] ~A requires a value." option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[update] --user and --system can't be used together."))
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
                  (error "[update] unknown option: ~S~%~A"
                         (car args)
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
       (error "[update] unknown update mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: search
;;;; ------------------------------------------------------------

(defun %get-taf-search-help-string ()
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
      (error "[search] ~A requires a positive integer, but got: ~S"
             option-name value))
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
                   (error "[search] ~A requires a value." option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[search] --user and --system can't be used together."))
                  (when (null positionals)
                    (error "[search] keyword missing.~%~A"
                           (%get-taf-search-help-string)))
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
                  (error "[search] -h/--help must be used alone.~%~A"
                         (%get-taf-search-help-string)))
                 ((option-like-p (car args))
                  (error "[search] unknown option: ~S~%~A"
                         (car args)
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
       (error "[search] unknown search mode: ~S" mode)))))

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
       (error "[~A] app name or command name missing.~%~A"
              label
              help-string))
      ((and (= (length items) 2)
            (%taf-hub-version-id-string-p (second items)))
       (list (list :query (first items)
                   :version-id (second items))))
      ((some #'%taf-hub-version-id-string-p items)
       (error "[~A] standalone VERSION-ID is only supported with one target. Use exact versioned command names for batch operations.~%~A"
              label
              help-string))
      (t
       (mapcar (lambda (item)
                 (list :query item :version-id nil))
               items)))))

(defun %get-taf-info-help-string ()
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
                    (error "[info] --user and --system can't be used together."))
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
                  (error "[info] -h/--help must be used alone.~%~A"
                         (%get-taf-info-help-string)))
                 ((option-like-p (car args))
                  (error "[info] unknown option: ~S~%~A"
                         (car args)
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
       (error "[info] unknown info mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: install
;;;; ------------------------------------------------------------

(defun %get-taf-install-help-string ()
  "Usage:
  taf install [-h | --help]
  taf install [-u | --user | -s | --system] [-n | --dry-run]
              [-f | --force] [--prompt]
              <APP-NAME|TAF-COMMAND>...
  taf install [-u | --user | -s | --system] [-n | --dry-run]
              [-f | --force] [--prompt]
              <APP-NAME|TAF-COMMAND> <VERSION-ID>
  taf install [-u | --user | -s | --system] [-n | --dry-run]
              [-f | --force] --from <PROJECT-DIR>

Install a TAFFISH app from the local index or a local project.

Details:
  - reads index/current.json for the selected scope
  - accepts package names, for example my-tool
  - accepts command names, for example taf-my-tool
  - accepts exact versioned command names, for example taf-my-tool-v0.1.0-r1
  - accepts multiple app/command targets in one command
  - defaults to the package latest version when VERSION-ID is omitted
  - for batch exact versions, prefer exact versioned command names
  - installs dependencies declared by the selected version record first
  - clones or copies the indexed source ref and builds the wrapper
  - installs the exact command, for example taf-my-tool-v0.1.0-r1
  - refreshes the unversioned command alias, for example taf-my-tool,
    to the latest installed local version
  - run `taf update` first if the local index is missing
  - --from installs a private/local TAFFISH project from PROJECT-DIR or
    any child directory by searching upward for taffish.toml, and records
    origin as [local-project] <PROJECT-ROOT>
  - --from does not read the index and does not auto-install dependencies

Options:
  -u, --user                Install into user home [default]
  -s, --system              Install app data into system home and command
                            into TAFFISH_SYSTEM_BIN_DIR [/usr/local/bin]
  -n, --dry-run             Print install plan without changing files
  -f, --force               Replace an existing installation of this version
  --from <PROJECT-DIR>      Install from a local TAFFISH project directory
  --prompt                  Allow git to ask credentials through terminal
  -h, --help                Show this help")

(defun %taf-install-targets-from-positionals (positionals)
  (%taf-hub-targets-from-positionals
   positionals
   "install"
   (%get-taf-install-help-string)))

(defun %parse-taf-install-args (raw-args)
  (let ((scope :user)
        (dry-run-p nil)
        (force-p nil)
        (prompt-p nil)
        (from-dir nil)
        (positionals nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((option-like-p (value)
               (and (stringp value)
                    (> (length value) 0)
                    (char= (char value 0) #\-)))
             (require-value (args option)
               (or (cadr args)
                   (error "[install] ~A requires a value." option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[install] --user and --system can't be used together."))
                  (cond
                    (from-dir
                     (when positionals
                       (error "[install] --from can't be combined with app/command targets.~%~A"
                              (%get-taf-install-help-string)))
                     (values :install-from-project
                             scope
                             nil
                             nil
                             dry-run-p
                             force-p
                             prompt-p
                             nil
                             from-dir))
                    (t
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
                               nil)))))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal)
                       (null positionals))
                  (values :help nil nil nil nil nil nil nil nil))
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
                 ((string= (car args) "--prompt")
                  (setf prompt-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--from")
                  (when from-dir
                    (error "[install] --from can only be given once."))
                  (setf from-dir (require-value args "--from"))
                  (parse (cddr args)))
                 ((and (member (car args) '("-h" "--help") :test #'string-equal)
                       positionals)
                  (error "[install] -h/--help must be used alone.~%~A"
                         (%get-taf-install-help-string)))
                 ((option-like-p (car args))
                  (error "[install] unknown option: ~S~%~A"
                         (car args)
                         (%get-taf-install-help-string)))
                 (t
                  (push (car args) positionals)
                  (parse (cdr args))))))
      (parse raw-args))))

(defun run-taf-install (raw-args)
  (multiple-value-bind
        (mode scope query version-id dry-run-p force-p prompt-p targets from-dir)
      (%parse-taf-install-args raw-args)
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
                                      :targets targets
                                      :dry-run-p dry-run-p
                                      :force-p force-p
                                      :prompt-p prompt-p)
           (taf.core:hub-install :scope scope
                                 :query query
                                 :version-id version-id
                                 :dry-run-p dry-run-p
                                 :force-p force-p
                                 :prompt-p prompt-p)))
      (t
       (error "[install] unknown install mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: list
;;;; ------------------------------------------------------------

(defun %get-taf-list-help-string ()
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
      (error "[list] ~A requires a positive integer, but got: ~S"
             option-name value))
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
                   (error "[list] ~A requires a value." option)))
             (parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[list] --user and --system can't be used together."))
                  (when (and local-seen-p online-seen-p)
                    (error "[list] --local and --online can't be used together."))
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
                  (error "[list] unknown option or argument: ~S~%~A"
                         (car args)
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
       (error "[list] unknown list mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: uninstall
;;;; ------------------------------------------------------------

(defun %get-taf-uninstall-help-string ()
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
                    (error "[uninstall] --user and --system can't be used together."))
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
                  (error "[uninstall] -h/--help must be used alone.~%~A"
                         (%get-taf-uninstall-help-string)))
                 ((option-like-p (car args))
                  (error "[uninstall] unknown option: ~S~%~A"
                         (car args)
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
       (error "[uninstall] unknown uninstall mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: hub: which
;;;; ------------------------------------------------------------

(defun %get-taf-which-help-string ()
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
                    (error "[which] --user and --system can't be used together."))
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
                  (error "[which] -h/--help must be used alone.~%~A"
                         (%get-taf-which-help-string)))
                 ((option-like-p (car args))
                  (error "[which] unknown option: ~S~%~A"
                         (car args)
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
       (error "[which] unknown which mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: doctor
;;;; ------------------------------------------------------------

(defun %get-taf-doctor-help-string ()
  "Usage:
  taf doctor [-h | --help]
  taf doctor [-u | --user | -s | --system]
  taf doctor [-i | --init] [-u | --user | -s | --system]

Check or initialize the local TAFFISH environment.

Details:
  - resolves TAFFISH_USER_HOME, TAFFISH_SYSTEM_HOME and TAFFISH_SYSTEM_BIN_DIR
  - checks required directories for the selected scope
  - checks TAFFISH_SYSTEM_BIN_DIR for system command launchers
  - checks required apps/index/images/bin/cache/share/logs directories
  - checks common executables: git, gh, docker, podman, apptainer,
    mksquashfs, squashfuse, fuse2fs, gocryptfs, taffish
  - checks whether the selected TAFFISH bin directory is in PATH
  - --init creates missing directories for the selected scope
  - --system --init requires root permission

Options:
  -i, --init                Create missing TAFFISH home directories
  -u, --user                Check or initialize user home [default]
  -s, --system              Check or initialize system home
  -h, --help                Show this help")

(defun %parse-taf-doctor-args (raw-args)
  (let ((init-p nil)
        (scope :user)
        (scope-seen-p nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[doctor] --user and --system can't be used together."))
                  (values :doctor init-p scope scope-seen-p))
                 ((and (null (cdr args))
                       (member (car args) '("-h" "--help") :test #'string-equal))
                  (values :help nil nil nil))
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
                 (t
                  (error "[doctor] unknown option: ~S~%~A"
                         (car args)
                         (%get-taf-doctor-help-string))))))
      (parse raw-args))))

(defun run-taf-doctor (raw-args)
  (multiple-value-bind (mode init-p scope scope-seen-p)
      (%parse-taf-doctor-args raw-args)
    (case mode
      (:help
       (format t "~A~%" (%get-taf-doctor-help-string)))
      (:doctor
       (when (and init-p
                  (not scope-seen-p)
                  (taf.core::%root-user-p))
         (error "[doctor] running `taf doctor --init` as root is ambiguous. Use --system explicitly, or --user with TAFFISH_USER_HOME."))
       (taf.core:system-doctor :init-p init-p
                               :scope scope))
      (t
       (error "[doctor] unknown doctor mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: config
;;;; ------------------------------------------------------------

(defun %get-taf-config-help-string ()
  "Usage:
  taf config [-h | --help]
  taf config [show] [-u | --user | -s | --system]
  taf config path [-u | --user | -s | --system]
  taf config init [-u | --user | -s | --system]
                  [--github | --china] [-f | --force]

Show or initialize TAFFISH runtime configuration.

Details:
  - reads TAFFISH_USER_HOME and TAFFISH_SYSTEM_HOME when set
  - falls back to ~/.local/share/taffish and /opt/taffish
  - reads config.toml from the selected TAFFISH home when present
  - reads TAFFISH_CONFIG as an explicit config file override when set
  - config controls index URL and source URL rewrite for installation
  - prints the active apps/index/images/bin/cache/share/logs paths
  - show/path do not check, create or repair directories

Options:
  -u, --user                Show user home as active scope [default]
  -s, --system              Show system home as active scope
  --github                  Initialize GitHub/default profile
  --china                   Initialize China mirror profile template
  -f, --force               Replace existing config file during init
  -h, --help                Show this help")

(defun %parse-taf-config-args (raw-args)
  (let ((scope :user)
        (mode :config)
        (profile :github)
        (force-p nil)
        (mode-seen-p nil)
        (profile-seen-p nil)
        (user-seen-p nil)
        (system-seen-p nil))
    (labels ((parse (args)
               (cond
                 ((null args)
                  (when (and user-seen-p system-seen-p)
                    (error "[config] --user and --system can't be used together."))
                  (values mode scope profile force-p))
                 ((member (car args) '("-h" "--help") :test #'string-equal)
                  (values :help nil nil nil))
                 ((member (car args) '("show" "path" "init") :test #'string-equal)
                  (when mode-seen-p
                    (error "[config] only one subcommand is allowed."))
                  (setf mode (cond
                               ((string-equal (car args) "show") :config)
                               ((string-equal (car args) "path") :path)
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
                    (error "[config] --github and --china can't be used together."))
                  (setf profile :github
                        profile-seen-p t)
                  (parse (cdr args)))
                 ((string= (car args) "--china")
                  (when profile-seen-p
                    (error "[config] --github and --china can't be used together."))
                  (setf profile :china
                        profile-seen-p t)
                  (parse (cdr args)))
                 ((%taf-option-p (car args) "-f" "--force")
                  (setf force-p t)
                  (parse (cdr args)))
                 (t
                  (error "[config] unknown option: ~S~%~A"
                         (car args)
                         (%get-taf-config-help-string))))))
      (parse raw-args))))

(defun run-taf-config (raw-args)
  (multiple-value-bind (mode scope profile force-p)
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
      (t
       (error "[config] unknown config mode: ~S" mode)))))

;;;; ------------------------------------------------------------
;;;; run: history
;;;; ------------------------------------------------------------

(defun %get-taf-history-help-string ()
  "Usage:
  taf history [-h | --help]
  taf history [-l | --last <N>] [-j | --json]
  taf history [-i | --id <RUN-ID>] [-j | --json]
  taf history [-p | --path]
  taf history [-c | --clear]

Show local TAFFISH execution provenance history.

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
      (error "[history] ~A requires a positive integer, but got: ~S"
             option-name value))
    n))

(defun %parse-taf-history-nonnegative-integer (value option-name)
  (let ((n (and value
                (ignore-errors
                  (parse-integer value :junk-allowed nil)))))
    (unless (and n (>= n 0))
      (error "[history] ~A requires a non-negative integer, but got: ~S"
             option-name value))
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
                 (error "[history] ~A requires a value." option))
               (cadr args))
             (parse (args)
               (cond
                 ((null args)
                  (unless status
                    (error "[history] --record-exec requires --status."))
                  (unless command
                    (error "[history] --record-exec requires --command."))
                  (unless exit-code
                    (error "[history] --record-exec requires --exit-code."))
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
                  (error "[history] unknown --record-exec option: ~S"
                         (car args))))))
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
                        (error "[history] --path and --clear can't be used together."))
                      (when (and (or path-p clear-p)
                                 (or id json-p (not (= last 20))))
                        (error "[history] --path/--clear can't be combined with query options."))
                      (values :history last id json-p path-p clear-p))
                     ((and (null (cdr args))
                           (member (car args) '("-h" "--help") :test #'string-equal))
                      (values :help nil nil nil nil nil))
                     ((%taf-option-p (car args) "-l" "--last")
                      (unless (cadr args)
                        (error "[history] --last requires N."))
                      (setf last (%parse-taf-history-positive-integer
                                  (cadr args) "--last"))
                      (parse (cddr args)))
                     ((%taf-option-p (car args) "-i" "--id")
                      (unless (cadr args)
                        (error "[history] --id requires RUN-ID."))
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
                      (error "[history] unknown option: ~S~%~A"
                             (car args)
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
       (error "[history] unknown history mode: ~S" mode)))))
