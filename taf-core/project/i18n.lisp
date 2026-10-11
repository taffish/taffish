(in-package :taf.core)

;;;; ============================================================
;;;; project/i18n.lisp
;;;; ============================================================

(defun %register-project-i18n-messages ()
  (dolist
      (entry
       '(("new.created"
          "[TAF] created new {kind} project: {path}"
          "[TAF] 已创建新的 {kind} 项目：{path}")
         ("check.header"
          "[TAF] project ok: {name}"
          "[TAF] 项目检查通过：{name}")
         ("check.field.root" "root" "根目录")
         ("check.field.kind" "kind" "类型")
         ("check.field.version" "version" "版本")
         ("check.field.license" "license" "许可证")
         ("check.field.repo" "repo" "仓库")
         ("check.field.command" "command" "命令")
         ("check.field.main" "main" "主文件")
         ("check.field.deps" "deps" "依赖")
         ("check.field.target" "target" "构建目录")
         ("check.field.image" "image" "镜像")
         ("check.field.docker" "docker" "Dockerfile")
         ("check.field.build" "build" "构建平台")
         ("check.field.smoke" "smoke" "冒烟测试")
         ("check.value.exists" "exists" "存在")
         ("check.value.missing" "missing" "缺失")
         ("check.smoke"
          "{backend}, timeout={timeout}, exist={exist}, test={test}"
          "{backend}，超时={timeout}，存在检查={exist}，命令测试={test}")
         ("build.building-image"
          "[TAF] building image: {image} ({backend})"
          "[TAF] 正在构建镜像：{image}（{backend}）")
         ("build.command"
          "[TAF] build command: {command}"
          "[TAF] 构建命令：{command}")
         ("build.built-command"
          "[TAF] built command: {path}"
          "[TAF] 已构建命令：{path}")
         ("build.command-current"
          "[TAF] command is up to date: {path}"
          "[TAF] 命令已是最新：{path}")
         ("build.synced-dependencies"
          "[TAF] synced dependencies: {count}"
          "[TAF] 已同步依赖：{count}")
         ("build.built-image"
          "[TAF] built image: {image} ({backend})"
          "[TAF] 已构建镜像：{image}（{backend}）")
         ("publish.initializing-git"
          "[TAF] initializing git repository."
          "[TAF] 正在初始化 git 仓库。")
         ("publish.adding-origin"
          "[TAF] adding git remote origin: {url}"
          "[TAF] 正在添加 git 远端 origin：{url}")
         ("publish.header.dry-run"
          "[TAF] publish dry-run: {name}"
          "[TAF] 发布试运行：{name}")
         ("publish.header.ready"
          "[TAF] publish ready: {name}"
          "[TAF] 发布就绪：{name}")
         ("publish.field.root" "root" "根目录")
         ("publish.field.repo" "repo" "仓库")
         ("publish.field.tag" "tag" "标签")
         ("publish.field.channel" "channel" "通道")
         ("publish.field.release-policy" "release policy" "Release 策略")
         ("publish.tag-only"
          "tag-only; GitHub Latest/Pre-release status is not changed"
          "仅发布 tag；不改变 GitHub Latest/Pre-release 状态")
         ("publish.field.build" "build" "构建")
         ("publish.field.release" "release" "发布说明")
         ("publish.field.message" "message" "消息")
         ("publish.field.notes" "notes" "说明文件")
         ("publish.field.prompt" "prompt" "交互认证")
         ("publish.field.create" "create" "创建仓库")
         ("publish.field.lock" "lock" "安全锁定")
         ("publish.field.remote" "remote" "远端")
         ("publish.field.latest" "latest" "最新标签")
         ("publish.field.warning" "warning" "警告")
         ("publish.field.outcome" "outcome" "结果")
         ("publish.field.phases" "phases" "阶段")
         ("publish.field.action" "action" "下一步")
         ("publish.field.plan" "plan" "计划")
         ("publish.yes" "yes" "是")
         ("publish.no" "no" "否")
         ("publish.remote.missing" "missing" "缺失")
         ("publish.remote.checked" "checked" "已检查")
         ("publish.remote.not-checked" "not checked" "未检查")
         ("publish.remote-check-skipped"
          "remote check skipped in dry-run: {error}"
          "试运行中已跳过远端检查：{error}")
         ("publish.action.manual-or-create"
          "use --yes to publish after creating the repository manually or adding --create-repo"
          "使用 --yes 发布；请先手动创建仓库或添加 --create-repo")
         ("publish.action.create-lock"
          "use --yes to create missing repo, lock release tags and publish"
          "使用 --yes 创建缺失仓库、锁定发布标签并发布")
         ("publish.action.create"
          "use --yes to create missing repo and publish"
          "使用 --yes 创建缺失仓库并发布")
         ("publish.action.release"
          "use --yes to run git commit/tag/push and create GitHub release"
          "使用 --yes 执行 git commit/tag/push 并创建 GitHub release")
         ("publish.action.git"
          "use --yes to run git commit/tag/push"
          "使用 --yes 执行 git commit/tag/push")
         ("publish.creating-repository"
          "[TAF] creating GitHub repository: {slug} ({visibility})"
          "[TAF] 正在创建 GitHub 仓库：{slug}（{visibility}）")
         ("publish.action-complete"
          "[TAF] {action}."
          "[TAF] {action}。")
         ("publish.creating-release"
          "[TAF] creating GitHub release: {tag}"
          "[TAF] 正在创建 GitHub release：{tag}")
         ("publish.committing"
          "[TAF] committing project changes."
          "[TAF] 正在提交项目改动。")
         ("publish.action.immutable-enabled"
          "enabled immutable releases for {slug}"
          "为 {slug} 启用了不可变 release")
         ("publish.action.ruleset-created"
          "created TAFFISH release tag ruleset for {slug}"
          "为 {slug} 创建了 TAFFISH 发布标签规则集")
         ("publish.status.ready" "ready" "就绪")
         ("publish.status.created" "created" "已创建")
         ("publish.status.resumed" "resumed" "已续传")
         ("publish.status.skipped" "skipped" "已跳过")
         ("publish.status.pending" "pending" "待执行")
         ("publish.status.conflict" "conflict" "冲突")
         ("publish.status.unavailable" "unavailable" "不可确认")
         ("publish.status.failed" "failed" "失败")
         ("publish.status.planned" "planned" "已规划")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.project.~A" suffix)
       english chinese))))

(%register-project-i18n-messages)

(defun %register-project-basic-error-i18n-messages ()
  (dolist
      (entry
       '(("error.positive-integer"
          "[new] {field} must be a positive integer, but got: {value}"
          "[new] {field} 必须是正整数，实际收到：{value}")
         ("error.repository-url"
          "{field} must be a repository URL, but got: {value}"
          "{field} 必须是仓库 URL，实际收到：{value}")
         ("error.github-repository-url"
          "{field} must be a GitHub repository URL, but got: {value}"
          "{field} 必须是 GitHub 仓库 URL，实际收到：{value}")
         ("error.kind-conflict"
          "[new] taf-app can't be tool and flow, must be one of them."
          "[new] taf-app 不能同时是 tool 和 flow，必须选择其中一种。")
         ("error.current-directory"
          "[project] can't get current directory."
          "[project] 无法获取当前目录。")
         ("error.project-root"
          "[project] can't find taffish.toml from current directory upward."
          "[project] 无法从当前目录向上找到 taffish.toml。")
         ("error.new-license-template"
          "[new] unsupported license: {license}. Supported license template: Apache-2.0"
          "[new] 不支持的许可证：{license}。支持的许可证模板：Apache-2.0")
         ("error.new-license"
          "[new] unsupported license: {license}"
          "[new] 不支持的许可证：{license}")
         ("error.new-name"
          "[new] invalid project name: {name}
Project name should use only letters, digits, '-' and '_', and must not start with '-' or '.'."
          "[new] 无效项目名称：{name}
项目名称只能使用字母、数字、'-' 和 '_'，且不能以 '-' 或 '.' 开头。")
         ("error.new-option-value"
          "[new] option {option} is missing its value."
          "[new] 选项 {option} 缺少参数值。")
         ("error.new-option-conflict"
          "[new] option {option} was provided multiple times."
          "[new] 选项 {option} 被重复提供。")
         ("error.new-arguments"
          "[new] invalid arguments: {detail}"
          "[new] 参数无效：{detail}")
         ("error.new-exists"
          "[new] project already exists: {path}"
          "[new] 项目已经存在：{path}")
         ("error.new-version"
          "[new] version must be a non-empty string without spaces, but got: {value}"
          "[new] version 必须是不含空白的非空字符串，实际收到：{value}")
         ("error.build-artifact-part"
          "[build] build artifact name part must not contain '/': {value}"
          "[build] 构建产物名称片段不能包含 '/'：{value}")
         ("error.directory-leaf"
          "Can't determine directory leaf name: {path}"
          "无法确定目录末级名称：{path}")
         ("error.build-chmod"
          "[build] chmod failed: {path}
{detail}"
          "[build] chmod 失败：{path}
{detail}")
         ("error.build-backend"
          "[build] image backend must be docker or podman, but got: {value}"
          "[build] 镜像后端必须是 docker 或 podman，实际收到：{value}")
         ("error.build-no-backend"
          "[build] can't find docker or podman executable."
          "[build] 找不到 docker 或 podman 可执行程序。")
         ("error.build-image-missing"
          "[build] missing [container].image in taffish.toml."
          "[build] taffish.toml 缺少 [container].image。")
         ("error.build-dockerfile-missing"
          "[build] missing [container].dockerfile in taffish.toml."
          "[build] taffish.toml 缺少 [container].dockerfile。")
         ("error.build-image-failed"
          "[build] image build failed with {code}.
{detail}"
          "[build] 镜像构建失败，退出码为 {code}。
{detail}")
         ("error.build-nothing"
          "[build] nothing to build."
          "[build] 没有需要构建的内容。")
         ("error.build-staging-invalid"
          "[build] staged artifact failed validation: {artifact}"
          "[build] 暂存构建产物验证失败：{artifact}")
         ("error.build-commit-invalid"
          "[build] installed artifact failed validation: {artifact}"
          "[build] 已安装构建产物验证失败：{artifact}")
         ("error.build-rename-invalid"
          "[build] artifact rename did not create the requested target.
  source : {source}
  target : {target}
  actual : {actual}"
          "[build] 构建产物重命名未创建请求的目标。
  源路径：{source}
  目标路径：{target}
  实际路径：{actual}")
         ("error.compile-backend"
          "[compile] container backend must be apptainer, podman or docker, but got: {value}"
          "[compile] 容器后端必须是 apptainer、podman 或 docker，实际收到：{value}")
         ("error.compile-backend-type"
          "[compile] container backend must be a string or keyword, but got: {value}"
          "[compile] 容器后端必须是字符串或 keyword，实际收到：{value}")
         ("error.compile-options"
          "[compile] malformed keyword options: {value}"
          "[compile] keyword 选项格式错误：{value}")
         ("error.compile-option"
          "[compile] unknown option: {value}"
          "[compile] 未知选项：{value}")
         ("error.compile-args"
          "[compile] ARGS must be a list, but got: {value}"
          "[compile] ARGS 必须是列表，实际收到：{value}")
         ("error.run-args"
          "[run] ARGS must be a list, but got: {value}"
          "[run] ARGS 必须是列表，实际收到：{value}")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.project.~A" suffix)
       english chinese))))

(%register-project-basic-error-i18n-messages)

(defun %register-project-check-error-i18n-messages ()
  (dolist
      (entry
       '(("error.check-toml-string-position"
          "[check] expected TOML string at position {position} in: {value}"
          "[check] 预期在位置 {position} 读取 TOML 字符串：{value}")
         ("error.check-toml-string-unterminated"
          "[check] unterminated TOML string: {value}"
          "[check] TOML 字符串未闭合：{value}")
         ("error.check-toml-escape-unterminated"
          "[check] unterminated TOML escape: {value}"
          "[check] TOML 转义未闭合：{value}")
         ("error.check-toml-escape"
          "[check] unsupported TOML escape \\{escape} in: {value}"
          "[check] 不支持的 TOML 转义 \\{escape}：{value}")
         ("error.check-toml-array-unterminated"
          "[check] unterminated TOML array: {value}"
          "[check] TOML 数组未闭合：{value}")
         ("error.check-toml-array-trailing"
          "[check] trailing characters after TOML array: {value}"
          "[check] TOML 数组后存在多余字符：{value}")
         ("error.check-toml-array-separator"
          "[check] expected comma or ] in TOML array: {value}"
          "[check] TOML 数组中预期为逗号或 ]：{value}")
         ("error.check-toml-string-trailing"
          "[check] trailing characters after TOML string: {value}"
          "[check] TOML 字符串后存在多余字符：{value}")
         ("error.check-toml-value"
          "[check] unsupported TOML value: {value}"
          "[check] 不支持的 TOML 值：{value}")
         ("error.check-toml-section-duplicate"
          "[check] duplicate TOML section: [{section}]"
          "[check] TOML section 重复：[{section}]")
         ("error.check-toml-line"
          "[check] invalid TOML line: {line}"
          "[check] 无效 TOML 行：{line}")
         ("error.check-toml-key-empty"
          "[check] empty TOML key in section [{section}]."
          "[check] section [{section}] 中存在空 TOML key。")
         ("error.check-toml-key-duplicate"
          "[check] duplicate TOML key: [{section}].{key}"
          "[check] TOML key 重复：[{section}].{key}")
         ("error.check-toml-key-before-section"
          "[check] TOML key appears before section: {line}"
          "[check] TOML key 出现在 section 之前：{line}")
         ("error.check-toml-section-missing"
          "[check] missing TOML section: [{section}]"
          "[check] 缺少 TOML section：[{section}]")
         ("error.check-toml-field-missing"
          "[check] missing TOML field: [{section}].{key}"
          "[check] 缺少 TOML 字段：[{section}].{key}")
         ("error.check-field-empty"
          "[check] {field} must be a non-empty string."
          "[check] {field} 必须是非空字符串。")
         ("error.check-field-string"
          "[check] {field} must be a string, but got: {value}"
          "[check] {field} 必须是字符串，实际收到：{value}")
         ("error.check-field-boolean"
          "[check] {field} must be true or false, but got: {value}"
          "[check] {field} 必须是 true 或 false，实际收到：{value}")
         ("error.check-path-relative"
          "[check] {field} must be relative to project root, but got: {value}"
          "[check] {field} 必须相对于项目根目录，实际收到：{value}")
         ("error.check-path-escape"
          "[check] {field} must not escape project root, but got: {value}"
          "[check] {field} 不能逃逸项目根目录，实际收到：{value}")
         ("error.check-kind"
          "[check] [package].kind must be \"tool\" or \"flow\", but got: {value}"
          "[check] [package].kind 必须是 \"tool\" 或 \"flow\"，实际收到：{value}")
         ("error.check-release"
          "[check] [package].release must be a positive integer, but got: {value}"
          "[check] [package].release 必须是正整数，实际收到：{value}")
         ("error.check-main-path"
          "[check] [package].main should point to a .taf file, but got: {value}"
          "[check] [package].main 应指向 .taf 文件，实际收到：{value}")
         ("error.check-platform-empty"
          "[check] [container].build_platforms contains an empty platform: {value}"
          "[check] [container].build_platforms 包含空平台：{value}")
         ("error.check-platform"
          "[check] invalid container platform {value} in [container].build_platforms."
          "[check] [container].build_platforms 中存在无效容器平台 {value}。")
         ("error.check-smoke-backend"
          "[check] [smoke].backend must be docker, podman or apptainer, but got: {value}"
          "[check] [smoke].backend 必须是 docker、podman 或 apptainer，实际收到：{value}")
         ("error.check-smoke-timeout"
          "[check] [smoke].timeout must be a positive integer, but got: {value}"
          "[check] [smoke].timeout 必须是正整数，实际收到：{value}")
         ("error.check-string-array"
          "[check] {field} must be an array of non-empty strings, but got: {value}"
          "[check] {field} 必须是非空字符串数组，实际收到：{value}")
         ("error.check-smoke-placeholder"
          "[check] {field} contains TODO placeholder: {value}.
  Replace default smoke checks with real app-specific checks before check/index."
          "[check] {field} 包含 TODO 占位符：{value}。
  请在 check/index 前将默认冒烟检查替换为该应用的真实检查。")
         ("error.check-smoke-required"
          "[check] containerized projects must define [smoke] with non-empty exist or test checks."
          "[check] 容器化项目必须定义 [smoke]，并提供非空 exist 或 test 检查。")
         ("error.check-smoke-empty"
          "[check] [smoke] must define at least one non-empty exist or test entry."
          "[check] [smoke] 必须至少定义一个非空 exist 或 test 条目。")
         ("error.check-dependency-command"
          "{prefix} dependency command must start with taf-, but got: {value}"
          "{prefix} 依赖命令必须以 taf- 开头，实际收到：{value}")
         ("error.check-dependency-empty"
          "{prefix} [dependencies].{command} must not be an empty array."
          "{prefix} [dependencies].{command} 不能为空数组。")
         ("error.check-main-missing"
          "[check] main TAF file does not exist: {path}"
          "[check] main TAF 文件不存在：{path}")
         ("error.check-flow-ref-unclosed"
          "{prefix} unclosed [[taf: ...]] dependency reference: {line}"
          "{prefix} [[taf: ...]] 依赖引用未闭合：{line}")
         ("error.check-flow-ref-empty"
          "{prefix} empty [[taf: ...]] dependency reference: {line}"
          "{prefix} [[taf: ...]] 依赖引用为空：{line}")
         ("error.check-flow-command"
          "{prefix} flow dependency command must start with taf-, but got: {value}"
          "{prefix} flow 依赖命令必须以 taf- 开头，实际收到：{value}")
         ("error.check-dependency-type"
          "{prefix} [dependencies].{command} must be a string or string array, but got: {value}"
          "{prefix} [dependencies].{command} 必须是字符串或字符串数组，实际收到：{value}")
         ("error.check-dependency-version"
          "[check] [dependencies].{command} must include exact main dependency version {required}, but got {actual}.
  main: {main}
  hint: run `taf build` to sync taffish.toml."
          "[check] [dependencies].{command} 必须包含 main 中的精确依赖版本 {required}，实际为 {actual}。
  main：{main}
  提示：运行 `taf build` 同步 taffish.toml。")
         ("error.check-dependencies-missing"
          "[check] [dependencies] is missing flow dependencies from main TAF file: {dependencies}.
  main: {main}
  hint: run `taf build` to sync taffish.toml."
          "[check] [dependencies] 缺少 main TAF 文件中的 flow 依赖：{dependencies}。
  main：{main}
  提示：运行 `taf build` 同步 taffish.toml。")
         ("error.check-image-tag"
          "[check] [container].image tag must match [package].version/release.
  image   : {image}
  tag     : {tag}
  expected: {expected}"
          "[check] [container].image 标签必须匹配 [package].version/release。
  镜像：{image}
  标签：{tag}
  预期：{expected}")
         ("error.check-image-unused"
          "[check] [container].image is set, but main TAF file has no static container tag using it.
  image: {image}
  main : {main}"
          "[check] 已设置 [container].image，但 main TAF 文件中没有使用它的静态 container tag。
  镜像：{image}
  main：{main}")
         ("error.check-image-mismatch"
          "[check] main TAF container image disagrees with [container].image.
  main line: {line}
  toml     : {toml}
  main     : {main}"
          "[check] main TAF 中的容器镜像与 [container].image 不一致。
  main 行号：{line}
  toml：{toml}
  main：{main}")
         ("error.check-name"
          "[check] [package].name is not a valid TAFFISH project name: {value}"
          "[check] [package].name 不是有效的 TAFFISH 项目名称：{value}")
         ("error.check-version"
          "[check] [package].version must be a non-empty string without spaces, but got: {value}"
          "[check] [package].version 必须是不含空白的非空字符串，实际收到：{value}")
         ("error.check-command"
          "[check] [command].name must start with \"taf-\", but got: {value}"
          "[check] [command].name 必须以 \"taf-\" 开头，实际收到：{value}")
         ("error.check-dockerfile"
          "[check] dockerfile does not exist: {path}"
          "[check] Dockerfile 不存在：{path}")
         ("error.check-platform-conflict"
          "[check] [container].build_platforms and legacy [container].platforms disagree."
          "[check] [container].build_platforms 与旧字段 [container].platforms 不一致。")
         ("error.check-help-missing"
          "[check] docs/help.md does not exist. It is required by built command --help."
          "[check] docs/help.md 不存在；构建后的命令需要它提供 --help。")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.project.~A" suffix)
       english chinese))))

(%register-project-check-error-i18n-messages)

(defun %register-project-publish-error-i18n-messages ()
  (dolist
      (entry
       '(("error.publish-utf8"
          "[publish] can't encode character as UTF-8: {value}"
          "[publish] 无法将字符编码为 UTF-8：{value}")
         ("error.publish-journal-key"
          "[publish] can't derive journal key from repository URL: {url}"
          "[publish] 无法从仓库 URL 推导发布事务记录键：{url}")
         ("error.publish-channel"
          "[publish] channel must be latest, pre or no-latest, but got: {value}"
          "[publish] channel 必须是 latest、pre 或 no-latest，实际收到：{value}")
         ("error.publish-visibility"
          "[publish] repository visibility must be public or private, but got: {value}"
          "[publish] 仓库可见性必须是 public 或 private，实际收到：{value}")
         ("error.publish-git-missing"
          "[publish] can't find git executable."
          "[publish] 找不到 git 可执行程序。")
         ("error.publish-gh-missing"
          "[publish] can't find gh executable. Install GitHub CLI or create the repository manually."
          "[publish] 找不到 gh 可执行程序。请安装 GitHub CLI，或手动创建仓库。")
         ("error.publish-env-missing"
          "[publish] can't find env executable."
          "[publish] 找不到 env 可执行程序。")
         ("publish.auth-hint"
          "TAF does not handle GitHub login. Please authenticate GitHub yourself, for example by using an SSH repository URL with a loaded key, configuring a git credential helper, or running `gh auth login` outside TAF."
          "TAF 不负责 GitHub 登录。请自行完成 GitHub 认证，例如使用已加载密钥的 SSH 仓库 URL、配置 git credential helper，或在 TAF 外运行 `gh auth login`。")
         ("publish.repository-missing-hint"
          "GitHub repository does not exist or is not accessible: {url}. Create it manually or rerun with --create-repo."
          "GitHub 仓库不存在或不可访问：{url}。请手动创建，或添加 --create-repo 后重新运行。")
         ("error.publish-git-command"
          "[publish] git command failed ({code}): git -C {root} {args}
{output}{hint}"
          "[publish] git 命令失败（{code}）：git -C {root} {args}
{output}{hint}")
         ("error.publish-origin-mismatch"
          "[publish] git remote origin does not match [repository].url.
  origin: {origin}
  toml  : {toml}"
          "[publish] git 远端 origin 与 [repository].url 不一致。
  origin：{origin}
  toml：{toml}")
         ("error.publish-git-status"
          "[publish] failed to inspect git status.
{output}"
          "[publish] 无法检查 git 状态。
{output}")
         ("error.publish-release-missing"
          "[publish] --release requires release.md in project root."
          "[publish] 使用 --release 时，项目根目录中必须存在 release.md。")
         ("error.publish-release-empty"
          "[publish] release.md is empty."
          "[publish] release.md 为空。")
         ("error.publish-release-title-empty"
          "[publish] first line of release.md is empty."
          "[publish] release.md 第一行为空。")
         ("error.publish-release-todo"
          "[publish] first line of release.md is still the default TODO release summary. Replace it before publishing."
          "[publish] release.md 第一行仍是默认 TODO 发布摘要；请替换后再发布。")
         ("error.publish-license-missing"
          "[publish] LICENSE is missing. Add a real LICENSE file before publishing."
          "[publish] 缺少 LICENSE。请在发布前添加真实的 LICENSE 文件。")
         ("error.publish-license-empty"
          "[publish] LICENSE is empty. Add a real LICENSE file before publishing."
          "[publish] LICENSE 为空。请在发布前添加真实的许可证内容。")
         ("error.publish-license-placeholder"
          "[publish] LICENSE is still a placeholder. Replace it with a real license before publishing."
          "[publish] LICENSE 仍是占位内容。请在发布前替换为真实许可证。")
         ("error.publish-github-slug"
          "[publish] can't derive GitHub owner/repo from repository URL: {url}"
          "[publish] 无法从仓库 URL 推导 GitHub owner/repo：{url}")
         ("error.publish-create-repository"
          "[publish] failed to create GitHub repository {slug}.
{output}{hint}"
          "[publish] 创建 GitHub 仓库 {slug} 失败。
{output}{hint}")
         ("error.publish-action"
          "[publish] failed to {action}.
{output}{hint}"
          "[publish] 无法{action}。
{output}{hint}")
         ("error.publish-create-release"
          "[publish] failed to create GitHub release {tag}.
{output}{hint}"
          "[publish] 创建 GitHub release {tag} 失败。
{output}{hint}")
         ("error.publish-no-commit"
          "[publish] git repository has no commit to tag."
          "[publish] git 仓库中没有可供创建标签的 commit。")
         ("error.publish-operation"
          "[publish] unknown operation: {value}"
          "[publish] 未知操作：{value}")
         ("error.publish-journal-conflict"
          "publish intent conflicts with the existing transaction journal ({field}). Use the same publish options and release.md, or inspect {file} manually."
          "发布意图与现有事务记录冲突（{field}）。请使用相同的发布选项和 release.md，或手动检查 {file}。")
         ("error.publish-commit-identity"
          "commit identity differs: expected {expected}, observed {actual}"
          "commit 标识不一致：预期 {expected}，实际 {actual}")
         ("error.publish-reconcile-unavailable"
          "could not confirm whether {operation} completed; rerun the same taf publish command after connectivity is restored. Last confirmed stage: {stage}"
          "无法确认 {operation} 是否完成；网络恢复后，请重新运行完全相同的 taf publish 命令。最后确认阶段：{stage}")
         ("error.publish-ref-not-ready"
          "{evidence} did not reach the required commit after {operation}; refusing to overwrite the remote ref"
          "{evidence} 在 {operation} 后未到达所需 commit；拒绝覆盖远端 ref")
         ("error.publish-operation-not-ready"
          "{operation} did not reach the required state.{cause}"
          "{operation} 未达到所需状态。{cause}")
         ("error.publish-inspection-unavailable"
          "{evidence}; rerun the same taf publish command after connectivity is restored. Last confirmed stage: {stage}"
          "{evidence}；网络恢复后，请重新运行完全相同的 taf publish 命令。最后确认阶段：{stage}")
         ("error.publish-inspection-state"
          "unknown inspection state: {value}"
          "未知检查状态：{value}")
         ("error.publish-version-order"
          "current version is not newer than remote latest tag {tag}. Use --pre for a pre-release publish."
          "当前版本不比远端最新标签 {tag} 更新。若要发布预发布版本，请使用 --pre。")
         ("error.publish-build-failed"
          "command-wrapper build failed before the release commit was established: {error}"
          "在发布 commit 建立前，command wrapper 构建失败：{error}")
         ("publish.phase.repository-manual"
          "repository must be created manually or with --create-repo"
          "必须手动创建仓库，或使用 --create-repo")
         ("publish.phase.repository-create"
          "missing repository will be created"
          "将创建缺失的仓库")
         ("publish.phase.project-valid"
          "project, repository URL and LICENSE are valid"
          "项目、仓库 URL 和 LICENSE 均有效")
         ("publish.phase.build-not-requested"
          "command-wrapper build was not requested"
          "未请求构建 command wrapper")
         ("publish.phase.build-planned"
          "command-wrapper build would be ensured before the release commit"
          "将在发布 commit 建立前确保 command wrapper 已构建")
         ("publish.phase.build-not-established"
          "release commit identity is not established yet"
          "发布 commit 身份尚未建立")
         ("publish.phase.build-identity-unavailable"
          "release identity inspection is unavailable before build"
          "构建前无法检查发布身份")
         ("publish.phase.build-current"
          "command wrapper and frozen snapshot are already up to date"
          "command wrapper 与冻结快照已经是最新状态")
         ("publish.phase.build-ready"
          "command wrapper and frozen snapshot were rebuilt transactionally"
          "command wrapper 与冻结快照已通过事务式构建完成")
         ("publish.phase.build-release-established"
          "release commit {commit} is already established; build was skipped"
          "发布 commit {commit} 已建立；跳过构建")
         ("publish.phase.release-incomplete"
          "GitHub Release response is invalid or missing required identity/type fields"
          "GitHub Release 响应无效或缺少必要的身份/类型字段")
         ("publish.phase.release-conflict"
          "GitHub Release exists but tag/title/notes/type intent differs, or it is a draft"
          "已有 GitHub Release 的 tag、标题、说明或类型与发布意图冲突，或它仍是草稿")
         ("publish.phase.release-matching"
          "GitHub Release tag/title/notes/type match; existing Latest selection is unchanged"
          "GitHub Release 的 tag、标题、说明及类型一致；保留已有 Latest 选择")
         ("publish.phase.complete"
          "Git tag and requested GitHub Release are complete"
          "Git 标签及请求的 GitHub Release 均已完成")
         ("publish.cause"
          " Cause: {error}"
          " 原因：{error}")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.project.~A" suffix)
       english chinese))))

(%register-project-publish-error-i18n-messages)

(defun %project-message (suffix &rest bindings)
  (apply #'taffish.i18n:message-with
         (format nil "taf.project.~A" suffix)
         bindings))

(defun %project-repr (value)
  (prin1-to-string value))

(defun %project-error (suffix &rest bindings)
  (error "~A"
         (apply #'%project-message
                (format nil "error.~A" suffix)
                bindings)))

(defun %project-print-message (suffix &rest bindings)
  (format t "~A~%" (apply #'%project-message suffix bindings)))

(defun %project-print-field (prefix suffix value &optional (width 8))
  (format t "  ~VA: ~A~%"
          width
          (%project-message (format nil "~A.field.~A" prefix suffix))
          value))
