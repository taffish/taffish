(in-package :taf.core)

;;;; ============================================================
;;;; system / doctor.lisp
;;;; ============================================================

(defparameter *taffish-doctor-executables*
  '(("git"       :required)
    ("gh"        :optional)
    ("docker"    :optional)
    ("podman"    :optional)
    ("apptainer" :optional)
    ("mksquashfs" :optional)
    ("squashfuse" :optional)
    ("fuse2fs" :optional)
    ("gocryptfs" :optional)
    ("taf"        :optional)
    ("taffish"   :optional)
    ("vim"        :optional)
    ("nvim"       :optional)))

(defparameter *taffish-doctor-backend-probes*
  '(("docker" "info" "--format" "{{.ServerVersion}}")
    ("podman" "info" "--format" "{{.Version.Version}}")
    ("apptainer" "version")))

(defparameter *taffish-doctor-probe-timeout-seconds* 2)

;; Tests may bind this without changing the process HOME or reading a real rc.
(defparameter *taffish-doctor-os-home-override* nil)

;; Tests may bind this to a function accepting one backend probe spec.
(defparameter *taffish-doctor-backend-probe-function* nil)

(defparameter *taffish-doctor-docs-base-url*
  "https://github.com/taffish/taffish")

(defun %doctor-docs-url (anchor)
  (format nil "~A#~A" *taffish-doctor-docs-base-url* anchor))

(defun %doctor-dir-result (relative-dir path init-p)
  (let ((exists-p (%directory-exists-p path)))
    (cond
      (exists-p
       (list :kind :directory
             :name relative-dir
             :path (%directory-namestring path)
             :status (if (%path-writable-p path) :ok :not-writable)))
      (init-p
       (handler-case
           (progn
             (%ensure-directory path)
             (list :kind :directory
                   :name relative-dir
                   :path (%directory-namestring path)
                   :status :created))
         (error (c)
           (list :kind :directory
                 :name relative-dir
                 :path (%directory-namestring path)
                 :status :error
                 :message (format nil "~A" c)))))
      (t
       (list :kind :directory
             :name relative-dir
             :path (%directory-namestring path)
             :status :missing)))))

(defun %doctor-executable-result (program requirement)
  (let ((path (han.os:find-executable program)))
    (list :kind :executable
          :name program
          :requirement requirement
          :path path
          :status (if path :ok :missing))))

(defun %doctor-bin-path-result (scope home system-bin-dir)
  (let ((bin-dir (%taffish-command-bin-dir scope home system-bin-dir)))
    (list :kind :path
          :name "command bin"
          :path (%directory-namestring bin-dir)
          :status
          (cond
            ((not (%directory-exists-p bin-dir)) :missing)
            ((not (%path-writable-p bin-dir)) :not-writable)
            ((not (%taffish-command-bin-dir-in-path-p bin-dir)) :not-in-path)
            (t :ok)))))

(defun %doctor-status (dir-results executable-results path-results)
  (cond
    ((find :error dir-results :key (lambda (item) (getf item :status)))
     :error)
    ((find :missing dir-results :key (lambda (item) (getf item :status)))
     :needs-init)
    ((find :missing path-results :key (lambda (item) (getf item :status)))
     :needs-init)
    ((find :not-writable dir-results :key (lambda (item) (getf item :status)))
     :permission-warning)
    ((find :not-writable path-results :key (lambda (item) (getf item :status)))
     :permission-warning)
    ((find-if (lambda (item)
                (and (eql (getf item :requirement) :required)
                     (eql (getf item :status) :missing)))
              executable-results)
     :missing-tools)
    ((find :not-in-path path-results :key (lambda (item) (getf item :status)))
     :path-warning)
    (t :ok)))

(defun %doctor-status-string (status)
  (string-downcase (string status)))

(defun %doctor-diagnostic (id status scope summary evidence remediation docs-url)
  (list :id id
        :status status
        :scope scope
        :summary summary
        :evidence evidence
        :remediation remediation
        :docs-url docs-url))

(defun %doctor-diagnostic-status (diagnostics)
  (cond
    ((find :error diagnostics :key (lambda (item) (getf item :status)))
     :error)
    ((find :warning diagnostics :key (lambda (item) (getf item :status)))
     :warning)
    ((find :unknown diagnostics :key (lambda (item) (getf item :status)))
     :unknown)
    (t :ok)))

(defun %doctor-items-with-status (items status)
  (mapcar (lambda (item) (getf item :name))
          (remove status items
                  :key (lambda (item) (getf item :status))
                  :test-not #'eql)))

(defun %doctor-file-readable-p (path)
  (and (han.path:file-exists-p path)
       (handler-case
           (with-open-file (in path :direction :input)
             (open-stream-p in)
             t)
         (error () nil))))

(defun %doctor-path-readable-p (path)
  (let ((shell (or (han.os:find-executable "sh")
                   (han.os:find-executable "bash"))))
    (when (and shell (%directory-exists-p path))
      (multiple-value-bind (out err code)
          (han.os:run-shell-command
           (format nil "test -r ~A"
                   (han.os:escape-sh-token (%directory-namestring path)))
           :lines nil
           :shell shell)
        (declare (ignore out err))
        (and (integerp code) (= code 0))))))

(defun %doctor-trim-output (value)
  (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return)
                              (or value ""))))
    (subseq trimmed 0 (min 240 (length trimmed)))))

(defun %doctor-home-diagnostic (scope home dir-results)
  (let ((errors (%doctor-items-with-status dir-results :error))
        (missing (%doctor-items-with-status dir-results :missing))
        (not-writable (%doctor-items-with-status dir-results :not-writable)))
    (cond
      (errors
       (%doctor-diagnostic
        :home :error scope
        "TAFFISH home contains directory errors."
        (list :home (%directory-namestring home) :errors errors)
        "Review the reported directory errors; doctor never changes ownership or permissions."
        (%doctor-docs-url "choose-user-or-system-scope")))
      (missing
       (%doctor-diagnostic
        :home :warning scope
        "TAFFISH home is not fully initialized."
        (list :home (%directory-namestring home) :missing missing)
        (format nil "Run `taf doctor --init --~A` to create TAFFISH-owned directories."
                (%doctor-status-string scope))
        (%doctor-docs-url "choose-user-or-system-scope")))
      (not-writable
       (%doctor-diagnostic
        :home :warning scope
        "Some TAFFISH home directories are not writable by the current user."
        (list :home (%directory-namestring home)
              :not-writable not-writable)
        "Use the matching user/system scope or ask an administrator to review ownership."
        (%doctor-docs-url "choose-user-or-system-scope")))
      (t
       (%doctor-diagnostic
        :home :ok scope
        "TAFFISH home directories are present."
        (list :home (%directory-namestring home))
        ""
        (%doctor-docs-url "choose-user-or-system-scope"))))))

(defun %doctor-config-diagnostic (scope user-home system-home)
  (handler-case
      (let* ((config
               (taffish.i18n:with-language ("en")
                 (%effective-taffish-config
                  :scope scope
                  :user-home user-home
                  :system-home system-home)))
             (files (getf config :config-files)))
        (%doctor-diagnostic
         :config :ok scope
         (if files
             "TAFFISH configuration files are valid."
             "Built-in TAFFISH configuration defaults are valid.")
         (list :loaded-files (coerce files 'vector)
               :profile (getf config :profile)
               :index-url (getf config :index-url))
         ""
         (%doctor-docs-url "runtime-config-and-mirrors")))
    (error (c)
      (%doctor-diagnostic
       :config :error scope
       "TAFFISH configuration could not be parsed."
       (list :error (format nil "~A" c))
       "Fix the reported config.toml or TAFFISH_CONFIG file before using Hub commands."
       (%doctor-docs-url "runtime-config-and-mirrors")))))

(defun %doctor-index-diagnostic (scope home)
  (let ((file (han.path:join-path home "index" "current.json")))
    (cond
      ((not (han.path:file-exists-p file))
       (%doctor-diagnostic
        :index :warning scope
        "The local TAFFISH index snapshot is missing."
        (list :file (han.path:->namestring file))
        (format nil "Run `taf update --~A` when network access is available."
                (%doctor-status-string scope))
        (%doctor-docs-url "basic-usage")))
      ((not (%doctor-file-readable-p file))
       (%doctor-diagnostic
        :index :error scope
        "The local TAFFISH index snapshot is not readable."
        (list :file (han.path:->namestring file))
        "Review file ownership and permissions; doctor will not change them."
        (%doctor-docs-url "basic-usage")))
      (t
       (%doctor-diagnostic
        :index :ok scope
        "The local TAFFISH index snapshot is readable."
        (list :file (han.path:->namestring file))
        ""
        (%doctor-docs-url "basic-usage"))))))

(defun %doctor-command-path-diagnostic (scope path-results executable-results)
  (let* ((path-item (first path-results))
         (path-status (getf path-item :status))
         (taf-item (find "taf" executable-results
                         :key (lambda (item) (getf item :name))
                         :test #'string=))
         (taffish-item (find "taffish" executable-results
                             :key (lambda (item) (getf item :name))
                             :test #'string=))
         (commands (list :taf (getf taf-item :path)
                         :taffish (getf taffish-item :path))))
    (if (eql path-status :ok)
        (%doctor-diagnostic
         :command-path :ok scope
         "The selected TAFFISH command directory is available on PATH."
         (list :bin (getf path-item :path) :commands commands)
         ""
         (%doctor-docs-url "choose-user-or-system-scope"))
        (%doctor-diagnostic
         :command-path :warning scope
         "The selected TAFFISH command directory is not ready on PATH."
         (list :bin (getf path-item :path)
               :path-status path-status
               :commands commands)
         (if (eql path-status :not-in-path)
             (%taffish-bin-path-export-command (getf path-item :path))
             "Initialize the selected TAFFISH home and review command-directory permissions.")
         (%doctor-docs-url "choose-user-or-system-scope")))))

(defun %doctor-normalize-shell (shell)
  (let ((value (cond
                 ((or (null shell) (eql shell :auto)) :auto)
                 ((keywordp shell) shell)
                 ((stringp shell)
                  (intern (string-upcase shell) :keyword))
                 (t shell))))
    (cond
      ((eql value :auto)
       (let* ((shell-env (han.host:getenv "SHELL"))
              (name (and shell-env
                         (pathname-name (pathname shell-env)))))
         (cond
           ((and name (string-equal name "bash")) :bash)
           ((and name (string-equal name "zsh")) :zsh)
           ((and name (string-equal name "fish")) :fish)
           (t :unknown))))
      ((member value '(:bash :zsh :fish) :test #'eql) value)
      (t
       (%doctor-error "shell" :value (prin1-to-string shell))))))

(defun %doctor-completion-files (home shell)
  (case shell
    (:bash
     (list (han.path:join-path home "share/completions/bash/taf")
           (han.path:join-path home "share/completions/bash/taffish")))
    (:zsh
     (list (han.path:join-path home "share/completions/zsh/_taf")
           (han.path:join-path home "share/completions/zsh/_taffish")))
    (:fish
     (list (han.path:join-path home "share/completions/fish/taf.fish")
           (han.path:join-path home "share/completions/fish/taffish.fish")))
    (t nil)))

(defun %doctor-os-home ()
  (or *taffish-doctor-os-home-override*
      (han.os:home-directory)))

(defun %doctor-file-contains-p (path needles)
  (when (han.path:file-exists-p path)
    (handler-case
        (let ((content (han.os:load-string path)))
          (every (lambda (needle)
                   (search needle content :test #'char=))
                 needles))
      (error () nil))))

(defun %doctor-completion-activated-p (home shell)
  (let ((os-home (%doctor-os-home))
        (root (%directory-namestring
               (%taffish-home-dir home "share/completions"))))
    (when os-home
      (case shell
        (:bash
         (or (%doctor-file-contains-p
              (han.path:join-path os-home ".bashrc")
              (list root "taf" "taffish"))
             (and (han.path:file-exists-p
                   (han.path:join-path os-home
                                       ".local/share/bash-completion/completions/taf"))
                  (han.path:file-exists-p
                   (han.path:join-path os-home
                                       ".local/share/bash-completion/completions/taffish")))))
        (:zsh
         (%doctor-file-contains-p
          (han.path:join-path os-home ".zshrc")
          (list root "compinit")))
        (:fish
         (and (han.path:file-exists-p
               (han.path:join-path os-home
                                   ".config/fish/completions/taf.fish"))
              (han.path:file-exists-p
               (han.path:join-path os-home
                                   ".config/fish/completions/taffish.fish"))))
        (t nil)))))

(defun %doctor-completion-remediation (home shell)
  (let ((root (string-right-trim
               '(#\/)
               (%directory-namestring
                (%taffish-home-dir home "share/completions")))))
    (case shell
      (:bash
       (format nil "Source ~A/bash/taf and ~A/bash/taffish from your Bash startup file."
               root root))
      (:zsh
       (format nil "Add ~A/zsh to fpath before running compinit."
               root))
      (:fish
       (format nil "Copy ~A/fish/*.fish into ~~/.config/fish/completions/."
               root))
      (t
       "Use `taf doctor --shell bash|zsh|fish` for shell-specific activation guidance."))))

(defun %doctor-completion-diagnostic (scope home requested-shell)
  (let* ((shell (%doctor-normalize-shell requested-shell))
         (files (%doctor-completion-files home shell))
         (missing (remove-if #'han.path:file-exists-p files)))
    (cond
      ((eql shell :unknown)
       (%doctor-diagnostic
        :shell-completion :unknown scope
        "The current shell could not be detected."
        (list :requested-shell requested-shell
              :shell-env (or (han.host:getenv "SHELL") "<unset>"))
        (%doctor-completion-remediation home shell)
        (%doctor-docs-url "shell-completion")))
      (missing
       (%doctor-diagnostic
        :shell-completion :warning scope
        "TAFFISH completion source files are missing."
        (list :shell shell
              :missing (mapcar #'han.path:->namestring missing))
        "Reinstall TAFFISH share files or restore the completion files for this scope."
        (%doctor-docs-url "shell-completion")))
      ((%doctor-completion-activated-p home shell)
       (%doctor-diagnostic
        :shell-completion :ok scope
        "TAFFISH completion files are installed and activation is detectable."
        (list :shell shell
              :files (mapcar #'han.path:->namestring files))
        ""
        (%doctor-docs-url "shell-completion")))
      (t
       (%doctor-diagnostic
        :shell-completion :unknown scope
        "TAFFISH completion files are installed, but activation cannot be confirmed."
        (list :shell shell
              :files (mapcar #'han.path:->namestring files))
        (%doctor-completion-remediation home shell)
        (%doctor-docs-url "shell-completion"))))))

(defun %doctor-vim-source-files (home)
  (list (han.path:join-path home "share/vim/syntax/taf.vim")
        (han.path:join-path home "share/vim/ftdetect/taf.vim")))

(defun %doctor-vim-activated-p ()
  (let ((os-home (%doctor-os-home)))
    (and os-home
         (or
          (and (han.path:file-exists-p
                (han.path:join-path os-home ".vim/syntax/taf.vim"))
               (han.path:file-exists-p
                (han.path:join-path os-home ".vim/ftdetect/taf.vim")))
          (and (han.path:file-exists-p
                (han.path:join-path os-home ".config/nvim/syntax/taf.vim"))
               (han.path:file-exists-p
                (han.path:join-path os-home ".config/nvim/ftdetect/taf.vim")))))))

(defun %doctor-vim-diagnostic (scope home executable-results)
  (let* ((files (%doctor-vim-source-files home))
         (missing (remove-if #'han.path:file-exists-p files))
         (editor-p
           (some (lambda (name)
                   (let ((item (find name executable-results
                                     :key (lambda (entry)
                                            (getf entry :name))
                                     :test #'string=)))
                     (and item (getf item :path))))
                 '("vim" "nvim"))))
    (cond
      ((not editor-p)
       (%doctor-diagnostic
        :vim-runtime :not-applicable scope
        "Neither Vim nor Neovim is installed; runtime activation is not applicable."
        (list :files (mapcar #'han.path:->namestring files))
        ""
        (%doctor-docs-url "vim-syntax-highlighting")))
      (missing
       (%doctor-diagnostic
        :vim-runtime :warning scope
        "TAFFISH Vim runtime source files are missing."
        (list :missing (mapcar #'han.path:->namestring missing))
        "Reinstall TAFFISH share files or restore share/vim for this scope."
        (%doctor-docs-url "vim-syntax-highlighting")))
      ((%doctor-vim-activated-p)
       (%doctor-diagnostic
        :vim-runtime :ok scope
        "TAFFISH Vim or Neovim runtime activation is detectable."
        (list :files (mapcar #'han.path:->namestring files))
        ""
        (%doctor-docs-url "vim-syntax-highlighting")))
      (t
       (%doctor-diagnostic
        :vim-runtime :unknown scope
        "TAFFISH Vim files are installed, but editor activation cannot be confirmed."
        (list :files (mapcar #'han.path:->namestring files))
        "Copy syntax/taf.vim and ftdetect/taf.vim into your Vim/Neovim runtime, or add the installed share/vim directory to runtimepath."
        (%doctor-docs-url "vim-syntax-highlighting"))))))

(defun %doctor-parse-octal-mode (string)
  (ignore-errors
    (parse-integer
     (string-trim '(#\Space #\Tab #\Newline #\Return) string)
     :radix 8
     :junk-allowed nil)))

(defun %doctor-directory-mode (path)
  (let ((stat (han.os:find-executable "stat"))
        (name (%directory-namestring path)))
    (when stat
      (dolist (arguments (list (list stat "-c" "%a" name)
                               (list stat "-f" "%Mp%Lp" name)))
        (multiple-value-bind (out err code)
            (han.os:run-program arguments
                                :output :string
                                :error-output :string
                                :ignore-error-status t)
          (declare (ignore err))
          (when (and (integerp code) (= code 0))
            (let ((mode (%doctor-parse-octal-mode out)))
              (when mode
                (return-from %doctor-directory-mode mode)))))))))

(defun %doctor-mode-string (mode)
  (and mode (format nil "~O" mode)))

(defun %doctor-world-writable-p (mode)
  (and mode (not (zerop (logand mode #o002)))))

(defun %doctor-sticky-p (mode)
  (and mode (not (zerop (logand mode #o1000)))))

(defun %doctor-sif-diagnostic (scope user-home system-home)
  (let* ((selected-home (if (eql scope :system) system-home user-home))
         (selected (%taffish-home-dir selected-home "images/sif"))
         (fallback (%taffish-home-dir user-home "images/sif"))
         (exists-p (%directory-exists-p selected))
         (readable-p (and exists-p (%doctor-path-readable-p selected)))
         (writable-p (and exists-p (%path-writable-p selected)))
         (fallback-writable-p
           (and (%directory-exists-p fallback)
                (%path-writable-p fallback)))
         (mode (and exists-p (%doctor-directory-mode selected)))
         (evidence (list :selected (%directory-namestring selected)
                         :exists (if exists-p "yes" "no")
                         :readable (if readable-p "yes" "no")
                         :writable (if writable-p "yes" "no")
                         :mode (or (%doctor-mode-string mode) "unknown")
                         :user-fallback (%directory-namestring fallback)
                         :user-fallback-writable
                         (if fallback-writable-p "yes" "no"))))
    (cond
      ((and writable-p
            (%doctor-world-writable-p mode)
            (not (%doctor-sticky-p mode)))
       (%doctor-diagnostic
        :apptainer-sif-cache :error scope
        "The Apptainer SIF cache is world-writable without the sticky bit."
        evidence
        "Ask an administrator to review the shared-cache policy; doctor will not run chmod or chown."
        (%doctor-docs-url "apptainer")))
      (writable-p
       (%doctor-diagnostic
        :apptainer-sif-cache :ok scope
        (if (and (%doctor-world-writable-p mode) (%doctor-sticky-p mode))
            "The Apptainer SIF cache is a writable sticky shared directory."
            "The Apptainer SIF cache is writable by the current user.")
        evidence
        ""
        (%doctor-docs-url "apptainer")))
      ((and (eql scope :system) readable-p fallback-writable-p)
       (%doctor-diagnostic
        :apptainer-sif-cache :ok scope
        "The system SIF cache is read-only and a writable user fallback is available."
        evidence
        ""
        (%doctor-docs-url "apptainer")))
      ((not exists-p)
       (%doctor-diagnostic
        :apptainer-sif-cache
        (if fallback-writable-p :warning :error)
        scope
        "The selected Apptainer SIF cache directory is missing."
        evidence
        (if (eql scope :user)
            "Run `taf doctor --init --user` to create the user cache."
            "Ask an administrator to initialize the system home, or initialize a writable user fallback.")
        (%doctor-docs-url "apptainer")))
      (t
       (%doctor-diagnostic
        :apptainer-sif-cache :error scope
        "No writable Apptainer SIF cache is available for this policy."
        evidence
        "Use a writable user cache, an administrator-prefilled readable system cache, or an explicitly approved sticky shared cache."
        (%doctor-docs-url "apptainer"))))))

(defun %doctor-bounded-shell-command (tokens timeout-seconds)
  (let ((command (format nil "~{~A~^ ~}"
                         (mapcar #'han.os:escape-sh-token tokens))))
    (han.os:run-shell-command
     (format nil
             "( exec ~A </dev/null ) & probe_pid=$!; ( sleep ~D; if kill -0 \"$probe_pid\" 2>/dev/null; then kill -KILL \"$probe_pid\" 2>/dev/null || true; exit 124; fi; exit 0 ) & watchdog_pid=$!; wait \"$probe_pid\"; probe_status=$?; if [ \"$probe_status\" -ge 128 ]; then wait \"$watchdog_pid\" 2>/dev/null; watchdog_status=$?; if [ \"$watchdog_status\" -eq 124 ]; then exit 124; fi; else kill \"$watchdog_pid\" 2>/dev/null || true; wait \"$watchdog_pid\" 2>/dev/null || true; fi; exit \"$probe_status\""
             command timeout-seconds)
     :lines nil)))

(defun %doctor-default-backend-probe (spec)
  (let* ((name (first spec))
         (path (han.os:find-executable name)))
    (if (null path)
        (list :name name :status :missing :path nil :exit-code nil :detail "")
        (multiple-value-bind (out err code)
            (%doctor-bounded-shell-command
             (cons path (rest spec))
             *taffish-doctor-probe-timeout-seconds*)
          (list :name name
                :status (cond
                          ((and (integerp code) (= code 0)) :ok)
                          ((and (integerp code) (= code 124)) :timeout)
                          (t :unavailable))
                :path path
                :exit-code code
                :detail (%doctor-trim-output
                         (if (and out (not (string= out ""))) out err)))))))

(defun %doctor-backend-probe (spec)
  (if *taffish-doctor-backend-probe-function*
      (funcall *taffish-doctor-backend-probe-function* spec)
      (%doctor-default-backend-probe spec)))

(defun %doctor-container-diagnostic (scope)
  (let* ((results (mapcar #'%doctor-backend-probe
                          *taffish-doctor-backend-probes*))
         (available (remove :ok results
                            :key (lambda (item) (getf item :status))
                            :test-not #'eql))
         (present (remove :missing results
                          :key (lambda (item) (getf item :status))
                          :test #'eql))
         (timed-out (find :timeout results
                          :key (lambda (item) (getf item :status)))))
    (cond
      (available
       (%doctor-diagnostic
        :container-backends :ok scope
        "At least one container backend passed its bounded readiness probe."
        (list :backends results)
        ""
        (%doctor-docs-url "container-backends")))
      ((null present)
       (%doctor-diagnostic
        :container-backends :warning scope
        "No supported container backend executable was found."
        (list :backends results)
        "Install Docker, Podman, or Apptainer before running containerized taf-apps."
        (%doctor-docs-url "container-backends")))
      (timed-out
       (%doctor-diagnostic
        :container-backends :unknown scope
        "Container backend readiness could not be confirmed before timeout."
        (list :backends results)
        "Check the backend service or machine manually; doctor does not start it."
        (%doctor-docs-url "container-backends")))
      (t
       (%doctor-diagnostic
        :container-backends :warning scope
        "Container backend commands exist, but none passed the readiness probe."
        (list :backends results)
        "Review the reported backend status; doctor does not start daemons or machines."
        (%doctor-docs-url "container-backends"))))))

(defun %doctor-build-diagnostics (scope user-home system-home home dir-results
                                  executable-results path-results shell)
  (list (%doctor-home-diagnostic scope home dir-results)
        (%doctor-config-diagnostic scope user-home system-home)
        (%doctor-index-diagnostic scope home)
        (%doctor-command-path-diagnostic scope path-results executable-results)
        (%doctor-completion-diagnostic scope home shell)
        (%doctor-vim-diagnostic scope home executable-results)
        (%doctor-sif-diagnostic scope user-home system-home)
        (%doctor-container-diagnostic scope)))

(defun %doctor-print-paths (scope user-home system-home)
  (format t "~A~%" (taffish.i18n:message "doctor.header"))
  (%print-display-fields
   (list (list (taffish.i18n:message "doctor.label.scope") (%doctor-human-scope scope))
         (list (taffish.i18n:message "doctor.label.user-home") (%directory-namestring user-home))
         (list (taffish.i18n:message "doctor.label.system-home") (%directory-namestring system-home)))))

(defun %doctor-print-dir-results (dir-results)
  (format t "~%~A~%" (taffish.i18n:message "doctor.heading.directories"))
  (dolist (item dir-results)
    (format t "  ~A : ~A~%"
            (getf item :name)
            (%doctor-human-status (getf item :status))))
  nil)

(defun %doctor-print-executable-results (executable-results)
  (format t "~%~A~%" (taffish.i18n:message "doctor.heading.executables"))
  (dolist (item executable-results)
    (format t "  ~A : ~A~%"
            (getf item :name)
            (or (getf item :path)
                (taffish.i18n:message
                 "doctor.missing-program"
                 (list
                  (cons
                   "requirement"
                   (taffish.i18n:message
                    (format nil "doctor.requirement.~A"
                            (%doctor-status-string
                             (getf item :requirement))))))))))
  nil)

(defun %doctor-print-path-results (path-results)
  (format t "~%~A~%" (taffish.i18n:message "doctor.heading.path"))
  (dolist (item path-results)
    (format t "  ~A : ~A~%"
            (getf item :path)
            (%doctor-human-status (getf item :status))))
  nil)

(defun %doctor-print-summary (status init-p scope)
  (format t "~%~A: ~A~%"
          (taffish.i18n:message "doctor.heading.legacy-status")
          (%doctor-human-status status))
  (when (and (not init-p) (eql status :needs-init))
    (format t "~A: taf doctor --init --~A~%"
            (taffish.i18n:message "doctor.label.hint")
            (string-downcase (string scope)))))

(defun %doctor-print-path-hints (path-results)
  (let ((missing (find :not-in-path path-results
                       :key (lambda (item) (getf item :status)))))
    (when missing
      (format t "~A: ~A~%  ~A~%"
              (taffish.i18n:message "doctor.label.hint")
              (taffish.i18n:message "doctor.path-hint")
              (%taffish-bin-path-export-command (getf missing :path))))))

(defun %doctor-print-diagnostic-item (item detail-p)
  (when (getf item :inspection)
    (write-string (%hub-diagnostic-text (getf item :inspection) (getf item :scope)))
    (when detail-p
      (format t "    ~A :~%~A~%" (taffish.i18n:message "doctor.label.evidence")
              (han.json:encode-json (%hub-diagnostic-json-value (getf item :evidence)) :indent 2)))
    (return-from %doctor-print-diagnostic-item nil))
  (format t "  [~A] ~A: ~A~%"
          (string-upcase (%doctor-human-status (getf item :status)))
          (%doctor-human-id (getf item :id))
          (%doctor-human-summary item))
  (when detail-p
    (%print-display-fields
     (list (list (taffish.i18n:message "doctor.label.evidence") (prin1-to-string (getf item :evidence)))
           (list (taffish.i18n:message "doctor.label.docs") (getf item :docs-url)))))
  (when (and (or detail-p (not (member (getf item :status) '(:ok :not-applicable))))
             (not (string= (getf item :remediation) "")))
    (format t "    ~A : ~A~%"
            (taffish.i18n:message "doctor.label.remediation")
            (%doctor-human-remediation item))))

(defun %doctor-print-diagnostics (diagnostics diagnostic-status detail-p)
  (format t "~%~A~%"
          (taffish.i18n:message
           "doctor.heading.diagnostics-status"
           (list (cons "status" (%doctor-human-status diagnostic-status)))))
  (let ((printed-p nil))
    (unless detail-p
      (let* ((inspections (loop for item in diagnostics
                                when (and (getf item :inspection)
                                          (not (member (getf item :status) '(:ok :not-applicable))))
                                  collect (getf item :inspection)))
             (scope (or (getf (first diagnostics) :scope) :user)))
        (when inspections
          (setf printed-p t)
          (write-string (%hub-diagnostic-summary-text inspections scope)))))
    (dolist (item diagnostics)
      (when (or detail-p
                (and (not (getf item :inspection))
                     (not (member (getf item :status) '(:ok :not-applicable) :test #'eql))))
        (setf printed-p t)
        (%doctor-print-diagnostic-item item detail-p)))
    (unless printed-p
      (format t "  ~A~%" (taffish.i18n:message "doctor.all-passed")))))

(defun %doctor-json-key (key)
  (string-downcase
   (substitute #\_ #\-
               (etypecase key
                 (keyword (symbol-name key))
                 (symbol (symbol-name key))
                 (string key)))))

(defun %doctor-plist-p (value)
  (and (consp value)
       (evenp (length value))
       (loop for key in value by #'cddr
             always (or (keywordp key) (symbolp key)))))

(defun %doctor-json-value (value)
  (cond
    ((null value) :null)
    ((han.json:json-object-p value) value)
    ;; Strings are vectors in Common Lisp, so they must be handled before the
    ;; general vector branch or JSON would contain arrays of characters.
    ((stringp value) value)
    ((vectorp value)
     (coerce (loop for item across value
                   collect (%doctor-json-value item))
             'vector))
    ((pathnamep value) (han.path:->namestring value))
    ((%doctor-plist-p value)
     (let ((object (han.json:make-json-object)))
       (loop for (key val) on value by #'cddr do
         (han.json:set-json object
                            (%doctor-json-key key)
                            (%doctor-json-value val)))
       object))
    ((listp value)
     (coerce (mapcar #'%doctor-json-value value) 'vector))
    ((or (keywordp value) (symbolp value))
     (%doctor-json-key value))
    ((or (numberp value) (eq value t)) value)
    (t (princ-to-string value))))

(defun %doctor-result-json (result)
  (let ((object (han.json:json-object
   (cons "schema_version" "taffish.doctor/v1")
   (cons "scope" (%doctor-status-string (getf result :scope)))
   (cons "init_p" (if (getf result :init-p) t :false))
   (cons "status" (%doctor-status-string (getf result :status)))
   (cons "diagnostic_status"
         (%doctor-status-string (getf result :diagnostic-status)))
   (cons "user_home" (getf result :user-home))
   (cons "system_home" (getf result :system-home))
   (cons "system_bin_dir" (getf result :system-bin-dir))
   (cons "home" (getf result :home))
   (cons "directories"
         (coerce (mapcar #'%doctor-json-value (getf result :directories))
                 'vector))
   (cons "executables"
         (coerce (mapcar #'%doctor-json-value (getf result :executables))
                 'vector))
   (cons "paths"
         (coerce (mapcar #'%doctor-json-value (getf result :paths))
                 'vector))
   (cons "diagnostics"
         (coerce (mapcar #'%doctor-json-value (getf result :diagnostics))
                 'vector)))))
    (when (getf result :check)
      (han.json:set-json object "check" (%doctor-status-string (getf result :check)))
      (han.json:set-json object "exit_code" (getf result :exit-code)))
    object))

(defun %doctor-inspection-diagnostic (inspection scope id)
  (let* ((state (getf inspection :state))
         (status (case state (:verified :ok) (:unverified :warning)
                       (:invalid :error) (t :unknown))))
    (append
     (%doctor-diagnostic
      id status scope
      (format nil "~A ~A: ~A"
              (or (getf inspection :package-name) "index")
              (or (getf inspection :version-id) "") (%doctor-status-string state))
      inspection
      (taffish.i18n:with-language ("en") (%hub-diagnostic-remediation inspection scope))
      (%doctor-docs-url "basic-usage"))
     (list :inspection inspection))))

(defun %doctor-print-hub-coverage (diagnostics targets)
  (let ((names (make-hash-table :test #'equal))
        (identities (make-hash-table :test #'equal)) (incomplete nil))
    (dolist (item diagnostics)
      (when (eq (getf item :id) :hub-installation)
        (let* ((inspection (getf item :inspection))
               (name (getf inspection :package-name))
               (version (getf inspection :version-id)))
          (when name (setf (gethash name names) t))
          (when (and name version) (setf (gethash (list name version) identities) t))
          (when (or (null version)
                    (some (lambda (issue)
                            (member (getf issue :code) '("read-error" "unsafe-path") :test #'equal))
                          (getf inspection :issues)))
            (setf incomplete t)))))
    (%hub-print-message (if targets "diagnostic.coverage-selected" "diagnostic.coverage-all")
                        :packages (hash-table-count names) :versions (hash-table-count identities))
    (when incomplete (%hub-print-message "diagnostic.coverage-incomplete"))))

(defun %doctor-specialized (check targets scope user-home system-home system-bin home json-p detail-p verbose)
  (let ((*hub-diagnostic-progress* (%hub-make-diagnostic-progress
                                   (and (eql check :hub) verbose (not json-p)))))
   (multiple-value-bind (index-result index) (%hub-diagnose-index home)
    (let ((diagnostics (list (%doctor-inspection-diagnostic index-result scope :index))))
      (when (eql check :hub)
        (dolist (inspection (%hub-diagnose-installations home targets))
          (let* ((name (getf inspection :package-name))
                 (packages (%hub-json-ref index "packages"))
                 (package (and name (%hub-json-ref packages name)))
                 (record (%hub-json-ref (%hub-json-ref package "versions") (or (getf inspection :version-id) "")))
                 (repository (or (%hub-json-string record "repository_url")
                                 (%hub-json-string package "repository_url"))))
            (setf (getf inspection :index-latest) (%hub-json-string package "latest")
                  (getf inspection :source-status)
                  (cond ((equal (getf inspection :origin-kind) "local-project") :local-project)
                        ((not (eql (getf index-result :state) :verified)) :unknown)
                        ((null package) :not-indexed)
                        ((or (null repository) (null (getf inspection :repository-url))) :unknown)
                        ((equal repository (getf inspection :repository-url)) :matching-index)
                        (t :mismatch))))
          (push (%doctor-inspection-diagnostic
                 inspection scope (if (eql (getf inspection :check-kind) :command-entry)
                                      :hub-command :hub-installation)) diagnostics)))
      (setf diagnostics (nreverse diagnostics))
      (let* ((status (%doctor-diagnostic-status diagnostics))
             (exit-code (if (some (lambda (d) (member (getf d :status) '(:error :unknown))) diagnostics) 1 0))
             (result (list :check check :scope scope :init-p nil :exit-code exit-code
                           :user-home (%directory-namestring user-home)
                           :system-home (%directory-namestring system-home)
                           :system-bin-dir (%directory-namestring system-bin)
                           :home (%directory-namestring home)
                           :directories nil :executables nil :paths nil
                           :status status :diagnostic-status status :diagnostics diagnostics)))
        (when verbose
          (if json-p
              (format t "~A~%" (han.json:encode-json (%doctor-result-json result)))
              (progn
                (%doctor-print-paths scope user-home system-home)
                (when (eq check :hub) (%doctor-print-hub-coverage diagnostics targets))
                (%doctor-print-diagnostics diagnostics status detail-p))))
        result)))))

(defun system-doctor (&key (init-p nil)
                        (scope :user)
                        user-home
                        system-home
                        system-bin-dir
                        (shell :auto)
                        (detail-p nil)
                        (json-p nil)
                        (check :environment)
                        targets
                        (verbose t))
  (let* ((normalized-check (cond ((member check '(:environment :index :hub)) check)
                                 ((equal check "environment") :environment)
                                 ((equal check "index") :index)
                                 ((equal check "hub") :hub)
                                 (t (%doctor-error "check"))))
         (normalized-scope (%normalize-taffish-scope scope))
         (user-home-path (%taffish-user-home user-home))
         (system-home-path (%taffish-system-home system-home))
         (system-bin-path (%taffish-system-bin-dir system-bin-dir))
         (home (%taffish-home :scope normalized-scope
                              :user-home user-home-path
                              :system-home system-home-path)))
    (when (or (and targets (not (eql normalized-check :hub)))
              (not (listp targets))
              (not (every #'%hub-non-empty-string-p targets))
              (and (not (eql normalized-check :environment))
                   (or init-p (not (eql shell :auto)))))
      (%doctor-error "check-options"))
    (unless (eql normalized-check :environment)
      (return-from system-doctor
        (%doctor-specialized normalized-check targets normalized-scope
                             user-home-path system-home-path system-bin-path home
                             json-p detail-p verbose)))
    (when (and init-p
               (eql normalized-scope :system)
               (not (%root-user-p)))
      (%doctor-error "init-system-root"))
    (let* ((dir-results
             (mapcar (lambda (item)
                       (%doctor-dir-result (car item) (cdr item) init-p))
                     (%taffish-home-required-dir-paths home)))
           (executable-results
             (mapcar (lambda (item)
                       (%doctor-executable-result (first item) (second item)))
                     *taffish-doctor-executables*))
           (path-results
             (list (%doctor-bin-path-result normalized-scope
                                            home
                                            system-bin-path)))
           (status (%doctor-status dir-results executable-results path-results))
           (diagnostics
             (%doctor-build-diagnostics normalized-scope
                                        user-home-path
                                        system-home-path
                                        home
                                        dir-results
                                        executable-results
                                        path-results
                                        shell))
           (diagnostic-status (%doctor-diagnostic-status diagnostics))
           (result (list :scope normalized-scope
                         :init-p init-p
                         :user-home (%directory-namestring user-home-path)
                         :system-home (%directory-namestring system-home-path)
                         :system-bin-dir (%directory-namestring system-bin-path)
                         :home (%directory-namestring home)
                         :directories dir-results
                         :executables executable-results
                         :paths path-results
                         :status status
                         :diagnostic-status diagnostic-status
                         :diagnostics diagnostics)))
      (when verbose
        (if json-p
            (format t "~A" (han.json:encode-json (%doctor-result-json result)))
            (progn
              (%doctor-print-paths normalized-scope user-home-path system-home-path)
              (%doctor-print-diagnostics diagnostics diagnostic-status detail-p)
              (when detail-p
                (%doctor-print-dir-results dir-results)
                (%doctor-print-executable-results executable-results)
                (%doctor-print-path-results path-results)
                (%doctor-print-summary status init-p normalized-scope)
                (%doctor-print-path-hints path-results)))))
      result)))
