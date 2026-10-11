(in-package :taf.core)

;;;; ============================================================
;;;; system / doctor-i18n.lisp
;;;; Human-only doctor rendering. Structured diagnostics stay English.
;;;; ============================================================

(dolist
    (entry
     '(("doctor.header" "[TAF] doctor" "[TAF] 环境诊断")
       ("doctor.error.check" "[doctor] check must be environment, index or hub." "[doctor] 检查模式必须是 environment、index 或 hub。")
       ("doctor.error.check-options" "[doctor] targets require hub mode; index/hub checks are read-only and do not accept init or shell selection." "[doctor] 仅 hub 模式接受目标；index/hub 为只读检查，不接受 init 或 shell 选择。")
       ("doctor.heading.diagnostics-status" "Diagnostics: {status}"
        "诊断：{status}")
       ("doctor.heading.directories" "Directories:" "目录：")
       ("doctor.heading.executables" "Executables:" "可执行程序：")
       ("doctor.heading.path" "Shell PATH:" "Shell PATH：")
       ("doctor.heading.legacy-status" "Legacy status" "兼容状态")
       ("doctor.label.scope" "scope" "作用域")
       ("doctor.label.user-home" "user home" "用户目录")
       ("doctor.label.system-home" "system home" "系统目录")
       ("doctor.label.evidence" "evidence" "证据")
       ("doctor.label.remediation" "remediation" "修复建议")
       ("doctor.label.docs" "docs" "文档")
       ("doctor.label.hint" "Hint" "提示")
       ("doctor.all-passed" "All applicable diagnostics passed."
        "所有适用诊断均已通过。")
       ("doctor.missing-program" "missing ({requirement})"
        "缺失（{requirement}）")
       ("doctor.path-hint" "add TAFFISH bin to your shell PATH:"
        "请将 TAFFISH 命令目录加入 shell PATH：")
       ("doctor.error.shell"
        "[doctor] shell must be auto, bash, zsh, or fish, but got: {value}"
        "[doctor] shell 必须是 auto、bash、zsh 或 fish，实际收到：{value}")
       ("doctor.error.init-system-root"
        "[doctor] --init --system requires root permission."
        "[doctor] --init --system 需要 root 权限。")
       ("doctor.status.ok" "ok" "正常")
       ("doctor.status.warning" "warning" "警告")
       ("doctor.status.error" "error" "错误")
       ("doctor.status.unknown" "unknown" "未知")
       ("doctor.status.not-applicable" "not-applicable" "不适用")
       ("doctor.status.missing" "missing" "缺失")
       ("doctor.status.created" "created" "已创建")
       ("doctor.status.not-writable" "not-writable" "不可写")
       ("doctor.status.not-in-path" "not-in-path" "不在 PATH 中")
       ("doctor.status.needs-init" "needs-init" "需要初始化")
       ("doctor.status.permission-warning" "permission-warning" "权限警告")
       ("doctor.status.missing-tools" "missing-tools" "缺少工具")
       ("doctor.status.path-warning" "path-warning" "PATH 警告")
       ("doctor.scope.user" "user" "用户")
       ("doctor.scope.system" "system" "系统")
       ("doctor.requirement.required" "required" "必需")
       ("doctor.requirement.optional" "optional" "可选")
       ("doctor.id.home" "home" "目录")
       ("doctor.id.config" "config" "配置")
       ("doctor.id.index" "index" "索引")
       ("doctor.id.command-path" "command-path" "命令路径")
       ("doctor.id.shell-completion" "shell-completion" "Shell 补全")
       ("doctor.id.vim-runtime" "vim-runtime" "Vim 运行时")
       ("doctor.id.apptainer-sif-cache" "apptainer-sif-cache"
        "Apptainer SIF 缓存")
       ("doctor.id.container-backends" "container-backends" "容器后端")
       ("doctor.summary.home.error" "TAFFISH home contains directory errors."
        "TAFFISH 目录中存在目录错误。")
       ("doctor.summary.home.missing" "TAFFISH home is not fully initialized."
        "TAFFISH 目录尚未完整初始化。")
       ("doctor.summary.home.not-writable"
        "Some TAFFISH home directories are not writable by the current user."
        "当前用户无法写入部分 TAFFISH 目录。")
       ("doctor.summary.home.ok" "TAFFISH home directories are present."
        "TAFFISH 目录均已存在。")
       ("doctor.summary.config.files" "TAFFISH configuration files are valid."
        "TAFFISH 配置文件有效。")
       ("doctor.summary.config.defaults"
        "Built-in TAFFISH configuration defaults are valid."
        "TAFFISH 内置默认配置有效。")
       ("doctor.summary.config.error" "TAFFISH configuration could not be parsed."
        "无法解析 TAFFISH 配置。")
       ("doctor.summary.index.missing" "The local TAFFISH index snapshot is missing."
        "本地 TAFFISH 索引快照缺失。")
       ("doctor.summary.index.unreadable"
        "The local TAFFISH index snapshot is not readable."
        "本地 TAFFISH 索引快照不可读。")
       ("doctor.summary.index.ok" "The local TAFFISH index snapshot is readable."
        "本地 TAFFISH 索引快照可读。")
       ("doctor.summary.command-path.ok"
        "The selected TAFFISH command directory is available on PATH."
        "所选 TAFFISH 命令目录已在 PATH 中可用。")
       ("doctor.summary.command-path.warning"
        "The selected TAFFISH command directory is not ready on PATH."
        "所选 TAFFISH 命令目录尚未在 PATH 中就绪。")
       ("doctor.summary.completion.shell-unknown"
        "The current shell could not be detected."
        "无法识别当前 shell。")
       ("doctor.summary.completion.missing"
        "TAFFISH completion source files are missing."
        "TAFFISH 补全源文件缺失。")
       ("doctor.summary.completion.ok"
        "TAFFISH completion files are installed and activation is detectable."
        "TAFFISH 补全文件已安装，并可确认已经激活。")
       ("doctor.summary.completion.activation-unknown"
        "TAFFISH completion files are installed, but activation cannot be confirmed."
        "TAFFISH 补全文件已安装，但无法确认是否激活。")
       ("doctor.summary.vim.not-applicable"
        "Neither Vim nor Neovim is installed; runtime activation is not applicable."
        "未安装 Vim 或 Neovim，无需检查运行时激活。")
       ("doctor.summary.vim.missing" "TAFFISH Vim runtime source files are missing."
        "TAFFISH Vim 运行时源文件缺失。")
       ("doctor.summary.vim.ok"
        "TAFFISH Vim or Neovim runtime activation is detectable."
        "可以确认 TAFFISH Vim 或 Neovim 运行时已经激活。")
       ("doctor.summary.vim.activation-unknown"
        "TAFFISH Vim files are installed, but editor activation cannot be confirmed."
        "TAFFISH Vim 文件已安装，但无法确认编辑器是否激活。")
       ("doctor.summary.sif.unsafe-shared"
        "The Apptainer SIF cache is world-writable without the sticky bit."
        "Apptainer SIF 缓存全局可写，但未设置 sticky bit。")
       ("doctor.summary.sif.shared-ok"
        "The Apptainer SIF cache is a writable sticky shared directory."
        "Apptainer SIF 缓存是可写且带 sticky bit 的共享目录。")
       ("doctor.summary.sif.user-ok"
        "The Apptainer SIF cache is writable by the current user."
        "当前用户可以写入 Apptainer SIF 缓存。")
       ("doctor.summary.sif.system-fallback"
        "The system SIF cache is read-only and a writable user fallback is available."
        "系统 SIF 缓存只读，同时存在可写的用户回退缓存。")
       ("doctor.summary.sif.missing"
        "The selected Apptainer SIF cache directory is missing."
        "所选 Apptainer SIF 缓存目录缺失。")
       ("doctor.summary.sif.unavailable"
        "No writable Apptainer SIF cache is available for this policy."
        "当前策略下没有可写的 Apptainer SIF 缓存。")
       ("doctor.summary.container.ok"
        "At least one container backend passed its bounded readiness probe."
        "至少一个容器后端通过了限时就绪探测。")
       ("doctor.summary.container.missing"
        "No supported container backend executable was found."
        "未找到受支持的容器后端可执行程序。")
       ("doctor.summary.container.timeout"
        "Container backend readiness could not be confirmed before timeout."
        "超时前无法确认容器后端是否就绪。")
       ("doctor.summary.container.unavailable"
        "Container backend commands exist, but none passed the readiness probe."
        "容器后端命令存在，但均未通过就绪探测。")
       ("doctor.remediation.home.error"
        "Review the reported directory errors; doctor never changes ownership or permissions."
        "请检查报告的目录错误；doctor 不会修改所有权或权限。")
       ("doctor.remediation.home.missing"
        "Run `taf doctor --init --{scope}` to create TAFFISH-owned directories."
        "运行 `taf doctor --init --{scope}` 创建 TAFFISH 管理的目录。")
       ("doctor.remediation.home.not-writable"
        "Use the matching user/system scope or ask an administrator to review ownership."
        "请选择匹配的用户/系统作用域，或请管理员检查目录所有权。")
       ("doctor.remediation.config.error"
        "Fix the reported config.toml or TAFFISH_CONFIG file before using Hub commands."
        "使用 Hub 命令前，请修复报告的 config.toml 或 TAFFISH_CONFIG 文件。")
       ("doctor.remediation.index.missing"
        "Run `taf update --{scope}` when network access is available."
        "网络可用时运行 `taf update --{scope}`。")
       ("doctor.remediation.index.unreadable"
        "Review file ownership and permissions; doctor will not change them."
        "请检查文件所有权和权限；doctor 不会修改它们。")
       ("doctor.remediation.command-path"
        "Initialize the selected TAFFISH home and review command-directory permissions."
        "请初始化所选 TAFFISH 目录并检查命令目录权限。")
       ("doctor.remediation.completion.shell-unknown"
        "Use `taf doctor --shell bash|zsh|fish` for shell-specific activation guidance."
        "使用 `taf doctor --shell bash|zsh|fish` 获取对应 shell 的激活指引。")
       ("doctor.remediation.completion.missing"
        "Reinstall TAFFISH share files or restore the completion files for this scope."
        "请重新安装 TAFFISH 共享文件，或恢复此作用域的补全文件。")
       ("doctor.remediation.completion.bash"
        "Source {first} and {second} from your Bash startup file."
        "请在 Bash 启动文件中 source {first} 和 {second}。")
       ("doctor.remediation.completion.zsh"
        "Add {directory} to fpath before running compinit."
        "运行 compinit 前，请将 {directory} 加入 fpath。")
       ("doctor.remediation.completion.fish"
        "Copy {directory}/*.fish into ~/.config/fish/completions/."
        "请将 {directory}/*.fish 复制到 ~/.config/fish/completions/。")
       ("doctor.remediation.vim.missing"
        "Reinstall TAFFISH share files or restore share/vim for this scope."
        "请重新安装 TAFFISH 共享文件，或恢复此作用域的 share/vim。")
       ("doctor.remediation.vim.activation"
        "Copy syntax/taf.vim and ftdetect/taf.vim into your Vim/Neovim runtime, or add the installed share/vim directory to runtimepath."
        "请将 syntax/taf.vim 和 ftdetect/taf.vim 复制到 Vim/Neovim 运行时目录，或将已安装的 share/vim 加入 runtimepath。")
       ("doctor.remediation.sif.unsafe-shared"
        "Ask an administrator to review the shared-cache policy; doctor will not run chmod or chown."
        "请管理员检查共享缓存策略；doctor 不会运行 chmod 或 chown。")
       ("doctor.remediation.sif.user-missing"
        "Run `taf doctor --init --user` to create the user cache."
        "运行 `taf doctor --init --user` 创建用户缓存。")
       ("doctor.remediation.sif.system-missing"
        "Ask an administrator to initialize the system home, or initialize a writable user fallback."
        "请管理员初始化系统目录，或初始化一个可写的用户回退缓存。")
       ("doctor.remediation.sif.unavailable"
        "Use a writable user cache, an administrator-prefilled readable system cache, or an explicitly approved sticky shared cache."
        "请使用可写的用户缓存、由管理员预填充的可读系统缓存，或明确批准且带 sticky bit 的共享缓存。")
       ("doctor.remediation.container.missing"
        "Install Docker, Podman, or Apptainer before running containerized taf-apps."
        "运行容器化 taf-app 前，请安装 Docker、Podman 或 Apptainer。")
       ("doctor.remediation.container.timeout"
        "Check the backend service or machine manually; doctor does not start it."
        "请手动检查后端服务或虚拟机；doctor 不会启动它。")
       ("doctor.remediation.container.unavailable"
        "Review the reported backend status; doctor does not start daemons or machines."
        "请检查报告的后端状态；doctor 不会启动守护进程或虚拟机。")))
  (apply #'taffish.i18n:register-message entry))

(defun %doctor-error (suffix &rest bindings)
  (error "~A"
         (apply #'taffish.i18n:message-with
                (format nil "doctor.error.~A" suffix)
                bindings)))

(defun %doctor-evidence-has-key-p (evidence key)
  (loop for (current value) on evidence by #'cddr
        thereis (and (eql current key) (progn value t))))

(defun %doctor-i18n-status-string (status)
  (string-downcase (string status)))

(defun %doctor-i18n-parse-octal-mode (string)
  (ignore-errors
    (parse-integer
     (string-trim '(#\Space #\Tab #\Newline #\Return) string)
     :radix 8
     :junk-allowed nil)))

(defun %doctor-i18n-world-writable-p (mode)
  (and mode (not (zerop (logand mode #o002)))))

(defun %doctor-i18n-sticky-p (mode)
  (and mode (not (zerop (logand mode #o1000)))))

(defun %doctor-human-status (status)
  (taffish.i18n:message
   (format nil "doctor.status.~A" (%doctor-i18n-status-string status))))

(defun %doctor-human-scope (scope)
  (taffish.i18n:message
   (format nil "doctor.scope.~A" (%doctor-i18n-status-string scope))))

(defun %doctor-human-id (id)
  (taffish.i18n:message
   (format nil "doctor.id.~A" (%doctor-i18n-status-string id))))

(defun %doctor-backends-all-missing-p (evidence)
  (let ((backends (getf evidence :backends)))
    (and backends
         (every (lambda (item) (eql (getf item :status) :missing))
                backends))))

(defun %doctor-sif-unsafe-shared-p (evidence)
  (let ((mode (%doctor-i18n-parse-octal-mode (getf evidence :mode))))
    (and (string= (getf evidence :writable) "yes")
         (%doctor-i18n-world-writable-p mode)
         (not (%doctor-i18n-sticky-p mode)))))

(defun %doctor-human-summary-key (item)
  (let ((id (getf item :id))
        (status (getf item :status))
        (evidence (getf item :evidence)))
    (case id
      (:home
       (cond ((eql status :error) "doctor.summary.home.error")
             ((getf evidence :missing) "doctor.summary.home.missing")
             ((getf evidence :not-writable) "doctor.summary.home.not-writable")
             (t "doctor.summary.home.ok")))
      (:config
       (cond ((eql status :error) "doctor.summary.config.error")
             ((plusp (length (or (getf evidence :loaded-files) #())))
              "doctor.summary.config.files")
             (t "doctor.summary.config.defaults")))
      (:index
       (case status
         (:warning "doctor.summary.index.missing")
         (:error "doctor.summary.index.unreadable")
         (t "doctor.summary.index.ok")))
      (:command-path
       (if (eql status :ok)
           "doctor.summary.command-path.ok"
           "doctor.summary.command-path.warning"))
      (:shell-completion
       (cond ((and (eql status :unknown)
                   (%doctor-evidence-has-key-p evidence :requested-shell))
              "doctor.summary.completion.shell-unknown")
             ((eql status :warning) "doctor.summary.completion.missing")
             ((eql status :ok) "doctor.summary.completion.ok")
             (t "doctor.summary.completion.activation-unknown")))
      (:vim-runtime
       (case status
         (:not-applicable "doctor.summary.vim.not-applicable")
         (:warning "doctor.summary.vim.missing")
         (:ok "doctor.summary.vim.ok")
         (t "doctor.summary.vim.activation-unknown")))
      (:apptainer-sif-cache
       (cond ((%doctor-sif-unsafe-shared-p evidence)
              "doctor.summary.sif.unsafe-shared")
             ((string= (getf evidence :exists) "no")
              "doctor.summary.sif.missing")
             ((and (eql status :ok)
                   (string= (getf evidence :writable) "yes"))
              (let ((mode (%doctor-i18n-parse-octal-mode
                           (getf evidence :mode))))
                (if (and (%doctor-i18n-world-writable-p mode)
                         (%doctor-i18n-sticky-p mode))
                    "doctor.summary.sif.shared-ok"
                    "doctor.summary.sif.user-ok")))
             ((eql status :ok) "doctor.summary.sif.system-fallback")
             (t "doctor.summary.sif.unavailable")))
      (:container-backends
       (cond ((eql status :ok) "doctor.summary.container.ok")
             ((eql status :unknown) "doctor.summary.container.timeout")
             ((%doctor-backends-all-missing-p evidence)
              "doctor.summary.container.missing")
             (t "doctor.summary.container.unavailable")))
      (t nil))))

(defun %doctor-human-summary (item)
  (let ((key (%doctor-human-summary-key item)))
    (if key (taffish.i18n:message key) (getf item :summary))))

(defun %doctor-completion-human-remediation (evidence)
  (let ((files (getf evidence :files))
        (shell (getf evidence :shell)))
    (case shell
      (:bash
       (taffish.i18n:message
        "doctor.remediation.completion.bash"
        (list (cons "first" (first files))
              (cons "second" (second files)))))
      (:zsh
       (taffish.i18n:message
        "doctor.remediation.completion.zsh"
        (list (cons "directory"
                    (han.path:->namestring
                     (han.path:parent-directory-pathname (first files)))))))
      (:fish
       (taffish.i18n:message
        "doctor.remediation.completion.fish"
        (list (cons "directory"
                    (han.path:->namestring
                     (han.path:parent-directory-pathname (first files)))))))
      (t (taffish.i18n:message
          "doctor.remediation.completion.shell-unknown")))))

(defun %doctor-human-remediation (item)
  (let ((id (getf item :id))
        (status (getf item :status))
        (scope (getf item :scope))
        (evidence (getf item :evidence))
        (original (getf item :remediation)))
    (cond
      ((string= original "") "")
      ((and (eql id :command-path)
            (eql (getf evidence :path-status) :not-in-path))
       original)
      ((eql id :home)
       (cond ((eql status :error)
              (taffish.i18n:message "doctor.remediation.home.error"))
             ((getf evidence :missing)
              (taffish.i18n:message
               "doctor.remediation.home.missing"
               (list (cons "scope" (%doctor-i18n-status-string scope)))))
             (t (taffish.i18n:message
                 "doctor.remediation.home.not-writable"))))
      ((eql id :config)
       (taffish.i18n:message "doctor.remediation.config.error"))
      ((eql id :index)
       (if (eql status :warning)
           (taffish.i18n:message
            "doctor.remediation.index.missing"
            (list (cons "scope" (%doctor-i18n-status-string scope))))
           (taffish.i18n:message "doctor.remediation.index.unreadable")))
      ((eql id :command-path)
       (taffish.i18n:message "doctor.remediation.command-path"))
      ((eql id :shell-completion)
       (cond ((%doctor-evidence-has-key-p evidence :requested-shell)
              (taffish.i18n:message
               "doctor.remediation.completion.shell-unknown"))
             ((eql status :warning)
              (taffish.i18n:message "doctor.remediation.completion.missing"))
             (t (%doctor-completion-human-remediation evidence))))
      ((eql id :vim-runtime)
       (taffish.i18n:message
        (if (eql status :warning)
            "doctor.remediation.vim.missing"
            "doctor.remediation.vim.activation")))
      ((eql id :apptainer-sif-cache)
       (cond ((%doctor-sif-unsafe-shared-p evidence)
              (taffish.i18n:message
               "doctor.remediation.sif.unsafe-shared"))
             ((string= (getf evidence :exists) "no")
              (taffish.i18n:message
               (if (eql scope :user)
                   "doctor.remediation.sif.user-missing"
                   "doctor.remediation.sif.system-missing")))
             (t (taffish.i18n:message
                 "doctor.remediation.sif.unavailable"))))
      ((eql id :container-backends)
       (taffish.i18n:message
        (cond ((eql status :unknown)
               "doctor.remediation.container.timeout")
              ((%doctor-backends-all-missing-p evidence)
               "doctor.remediation.container.missing")
              (t "doctor.remediation.container.unavailable"))))
      (t original))))
