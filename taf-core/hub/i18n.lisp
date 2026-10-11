(in-package :taf.core)

;;;; ============================================================
;;;; hub/i18n.lisp
;;;; ============================================================

(defun %register-hub-i18n-messages ()
  (dolist
      (entry
       '(("diagnostic.progress" "[TAF] Checking local installations: {completed}/{total}" "[TAF] 正在检查本地安装：{completed}/{total}")
         ("repair.summary" "[TAF] Repair plan: {total} installed targets; {repair} rebuild, {skip} unchanged, {blocked} blocked; {absent} absent targets skipped." "[TAF] 修复计划：{total} 个已安装目标；{repair} 个需重建，{skip} 个不变，{blocked} 个受阻；跳过 {absent} 个未安装目标。")
         ("repair.preview" "Preview only. No installations changed. Repair retains backups and adds no apps, versions or dependencies." "仅预览，未修改安装。修复保留备份，不新增应用、版本或依赖。")
         ("repair.preview-batch" "To apply this selection: taf install {selector} --repair --{scope} --kind {kind} --yes" "确认执行当前范围：taf install {selector} --repair --{scope} --kind {kind} --yes")
         ("repair.preview-explicit" "To apply these explicit targets, rerun the same command without --dry-run." "确认执行这些指定目标时，以相同参数重试并去掉 --dry-run。")
         ("repair.scope.index-latest" "[TAF] Repair scope: {scope}, installed index.latest versions, kind={kind}. Other historical versions are not checked." "[TAF] 修复范围：{scope}，已安装的 index.latest 版本，类型={kind}；不检查其他历史版本。")
         ("repair.scope.installed-all-versions" "[TAF] Repair scope: {scope}, all installed versions including historical versions, kind={kind}. No upgrades or new installations." "[TAF] 修复范围：{scope}，全部已安装版本（含历史版本），类型={kind}；不升级、不新增安装。")
         ("repair.scope.explicit" "[TAF] Repair scope: {scope}, explicitly selected installed versions." "[TAF] 修复范围：{scope}，明确指定的已安装版本。")
         ("error.repair-installed-requires-repair" "[install] all-installed selection requires repair mode." "[install] 全部已安装版本的选择方式必须配合修复模式。")
         ("repair.reason.kind-unknown" "The installed app kind cannot be confirmed; this target cannot safely be excluded by the kind filter." "无法确认已安装应用的类型；不能按类型筛选静默排除此目标。")
         ("repair.blocked-hint" "No batch writes are allowed while a target is blocked. Inspect: taf doctor hub --{scope} --verbose. Confirm origins, formats, permissions and fixed source commits before retrying; do not use --force to bypass these checks." "存在受阻目标时不执行整批写入。请查看 taf doctor hub --{scope} --verbose，核对来源、格式、权限及固定源码 commit 后重试；不要用 --force 绕过检查。")
         ("error.repair-conflict" "[install] --repair cannot be combined with --force, --from, --prune-old or a caller-supplied record." "[install] --repair 不能与 --force、--from、--prune-old 或调用方提供的记录同时使用。")
         ("error.repair-batch-blocked" "[install] Repair blocked before changes.
{details}" "[install] 已在修改前停止修复。
{details}")
         ("error.repair-partial" "[install] Repair stopped after {count} completed targets; earlier repairs remain committed. Recovery records: {records}; command entry backups: {bin}. {detail}" "[install] 修复在完成 {count} 个目标后停止；已完成项保留。恢复记录：{records}；命令入口备份目录：{bin}。{detail}")
         ("repair.completed" "[TAF] Rebuilt {count} installed targets. Backups and journals are retained." "[TAF] 已重建 {count} 个已安装目标，备份和事务日志已保留。")
         ("repair.records" "Recovery records" "恢复记录")
         ("repair.entry-backups" "Entry backups (.taffish-repair-*)" "命令入口备份（.taffish-repair-*）")
         ("status.repair" "rebuild" "重建")
         ("status.blocked" "blocked" "受阻")
         ("diagnostic.summary" "Diagnostics ({scope}): issues affect {packages} apps, {versions} identities; {issues} issues." "诊断（{scope}）：问题涉及 {packages} 个应用、{versions} 个版本身份，共 {issues} 项问题。")
         ("diagnostic.coverage-all" "Inspection scope: all installed versions. Enumerated {packages} apps, {versions} version identities." "检查范围：全部已安装版本。已枚举 {packages} 个应用、{versions} 个版本身份。")
         ("diagnostic.coverage-selected" "Inspection scope: selected installed targets. Enumerated {packages} apps, {versions} version identities." "检查范围：指定的已安装目标。已枚举 {packages} 个应用、{versions} 个版本身份。")
         ("diagnostic.coverage-incomplete" "Some paths could not be fully inspected; these counts do not establish a complete, verified inventory." "部分路径无法完整检查；以上计数不代表已完整枚举或全部通过验证。")
         ("diagnostic.group" "{count} affected; examples: {examples}" "涉及 {count} 个目标；示例：{examples}")
         ("diagnostic.summary-details" "Full evidence: taf doctor hub --{scope} --verbose (or --json)." "完整证据：taf doctor hub --{scope} --verbose（或 --json）。")
         ("diagnostic.summary-remedy.access" "Check the reported paths and permissions with the owner; do not blindly chmod or overwrite." "请与所有者检查路径和权限，不要盲目 chmod 或覆盖。")
         ("diagnostic.summary-remedy.schema" "Check client/schema compatibility; unknown formats must not be overwritten." "请核对客户端与格式兼容性，不要覆盖未知格式。")
         ("diagnostic.summary-remedy.index" "Refresh the selected index when online: taf update --{scope}." "网络可用时刷新所选索引：taf update --{scope}。")
         ("diagnostic.summary-remedy.alias" "Inspect command shortcuts separately; use verified versioned commands meanwhile." "请单独检查命令快捷入口；可以暂用已验证的带版本命令。")
         ("diagnostic.summary-remedy.private" "Keep private installs; recover from the original local project, not the public index." "请保留私有安装，从原本地项目恢复，不要用公共索引覆盖。")
         ("diagnostic.summary-remedy.repair" "Preview repairs for all installed versions, including historical versions: taf install --all-installed --repair --{scope}. Unverifiable targets remain blocked; do not force overwrite." "预览全部已安装版本（含历史版本）的修复：taf install --all-installed --repair --{scope}。无法安全确认的目标仍会受阻；不要强制覆盖。")
         ("diagnostic.summary-remedy.inspect" "Inspect the original source and metadata before choosing a recovery operation." "请先检查原始来源与安装记录，再选择恢复操作。")
         ("diagnostic.phase.enumerate" "[TAF] Scanning local installation records..." "[TAF] 正在读取本地安装记录……")
         ("diagnostic.phase.aliases" "[TAF] Checking command shortcuts..." "[TAF] 正在检查命令快捷入口……")
         ("diagnostic.phase.done" "[TAF] Local installation checks complete." "[TAF] 本地安装检查完成。")
         ("diagnostic.phase.failed" "[TAF] Local installation checks stopped." "[TAF] 本地安装检查已停止。")
         ("diagnostic.phase.repair" "[TAF] Rebuilding installed apps: {completed}/{total} complete..." "[TAF] 正在重建已安装应用：已完成 {completed}/{total}……")
         ("diagnostic.phase.repair-done" "[TAF] Repair complete: {completed}/{total}. Backups retained." "[TAF] 修复完成：{completed}/{total}。备份已保留。")
         ("diagnostic.phase.repair-failed" "[TAF] Repair stopped: {completed}/{total} complete. See the recovery details." "[TAF] 修复停止：已完成 {completed}/{total}。请查看恢复信息。")
         ("diagnostic.manifest-missing" "Build manifest is missing; integrity is unverified." "缺少构建校验清单，完整性未验证。")
         ("diagnostic.manifest-invalid" "Build manifest is malformed or incomplete." "构建校验清单损坏或字段不完整。")
         ("diagnostic.manifest-schema" "Build manifest schema is not supported." "当前不支持此构建清单格式。")
         ("diagnostic.metadata-invalid" "Install metadata is missing, malformed or incomplete." "安装元数据缺失、损坏或字段不完整。")
         ("diagnostic.metadata-path" "Install metadata paths do not match the managed installation layout." "安装记录中的路径与实际受管理的安装位置不一致。")
         ("diagnostic.metadata-schema" "Install metadata schema is not supported." "当前不支持此安装记录格式。")
         ("diagnostic.metadata-schema-missing" "Legacy install metadata has no schema declaration; its format is unverified." "旧安装记录未声明格式版本，格式兼容性未验证。")
         ("diagnostic.alias-missing" "The unversioned command entry is missing or inaccessible." "不带版本号的命令入口缺失或不可访问。")
         ("diagnostic.alias-unrecognized" "The unversioned command entry does not match the expected local version; it was not executed." "不带版本号的命令入口与预期本地版本不符；未执行它。")
         ("diagnostic.alias-impact" "This warning concerns the command shortcut, not the integrity of versioned artifacts." "此警告针对命令快捷入口，不表示版本化产物损坏。")
         ("diagnostic.remedy.alias" "Inspect the reported entry and permissions. Use the versioned command {command} only if its separate installation check passes; back up local changes before any explicit reinstall. Doctor does not rewrite shortcuts." "请检查该入口及权限。只有对应安装检查通过后，才使用带版本命令 {command}；显式重装前先备份本地修改。doctor 不改写命令入口。")
         ("error.unsafe-installed-path" "[hub] refusing to remove an installation with inconsistent or unsafe paths: {path}. Inspect the metadata and restore the managed paths first; no files were removed by this deletion step." "[hub] 拒绝删除路径不一致或不安全的安装：{path}。请先检查安装记录并恢复正确的受管理路径；本次删除步骤未删除任何文件。")
         ("error.unsupported-install-schema" "[hub] refusing to remove an installation with an unsupported metadata schema: {path}. Check client compatibility first." "[hub] 拒绝删除使用未知记录格式的安装：{path}。请先检查客户端与格式的兼容性。")
         ("diagnostic.identity-mismatch" "Installed identity does not match its metadata or manifest." "安装身份与元数据或清单不一致。")
         ("diagnostic.wrapper-digest" "Wrapper checksum differs from the build manifest." "命令脚本摘要与构建清单不一致。")
         ("diagnostic.snapshot-digest" "Frozen snapshot checksum differs from the build manifest." "冻结快照摘要与构建清单不一致。")
         ("diagnostic.snapshot-metadata" "Frozen project metadata cannot be parsed or its main path is invalid." "冻结项目元数据无法解析，或 main 路径无效。")
         ("diagnostic.launcher-unrecognized" "Launcher differs from the recognized template; it was not executed." "启动器不是已识别模板；未执行它，暂不能验证。")
         ("diagnostic.read-error" "Cannot safely read or inspect this path." "无法安全读取或检查此路径。")
         ("diagnostic.file-missing" "Required file or directory is missing or has the wrong type." "必要文件或目录缺失，或类型不正确。")
         ("diagnostic.not-executable" "Command file is not executable." "命令文件没有可执行权限。")
         ("diagnostic.unsafe-path" "Path escapes the installation or contains an unsupported link/cycle." "路径超出安装范围，或存在不支持的链接/循环。")
         ("diagnostic.index-missing" "Local index is missing; local installation checks can still run." "本地索引缺失，但仍可检查本地安装。")
         ("diagnostic.index-json" "Local index is not a valid JSON object." "本地索引不是有效的 JSON 对象。")
         ("diagnostic.index-schema" "Local index schema is not supported." "当前不支持此本地索引格式。")
         ("diagnostic.index-packages" "Local index has no valid packages object." "本地索引缺少有效的 packages 对象。")
         ("diagnostic.index-latest" "Index latest points to a missing version record." "索引 latest 指向不存在的版本记录。")
         ("diagnostic.index-record" "Index package/version identity or required structure is inconsistent." "索引包/版本身份或必要结构不一致。")
         ("diagnostic.target-missing" "Requested installed app was not found." "未找到指定的已安装应用。")
         ("diagnostic.impact" "Unverified or damaged installations are not safe automatic-pruning evidence." "未验证或损坏的安装不能作为自动清理的安全依据。")
         ("diagnostic.index-impact" "Index-dependent maintenance cannot rely on this snapshot; local installation checks remain separate." "依赖索引的维护不能以此快照为依据；本地安装检查仍独立进行。")
         ("diagnostic.inspect-command" "Read-only detail: {command}" "只读查看详情：{command}")
         ("diagnostic.remedy.access" "Review the reported path and permissions with its owner; do not blindly chmod or overwrite it." "请与文件所有者检查路径和权限；不要盲目 chmod 或覆盖。")
         ("diagnostic.remedy.schema" "Check client/schema compatibility before reinstalling; do not overwrite unknown formats." "先检查客户端与格式兼容性；不要覆盖未知格式。")
         ("diagnostic.remedy.index" "Refresh the selected local index when network is available: {command}. If the issue persists, report it to the index maintainer." "网络可用时刷新对应本地索引：{command}。若仍有问题，请向索引维护者报告。")
         ("diagnostic.remedy.target" "Use taf list in the same scope and check the app or versioned command name." "请在相同作用域使用 taf list，核对应用名或带版本命令名。")
         ("diagnostic.remedy.private" "Back up local edits and inspect the original private project; reinstall explicitly with taf install --from if needed. Do not replace it from the public index." "先备份本地修改并检查原私有项目；必要时显式用 taf install --from 重装，不要用公共索引覆盖。")
         ("diagnostic.remedy.reinstall" "An unverified install may be intentional. Preview safe rebuilding from the fixed indexed source: {command}. Review the plan before removing --dry-run; blocked targets are not overwritten." "未验证安装可能是有意保留的。先预览从索引固定来源安全重建：{command}。确认计划后再去掉 --dry-run；受阻目标不会被覆盖。")
         ("diagnostic.remedy.inspect" "Inspect and back up the reported installation first; recover its original source before choosing any overwrite command." "请先检查并备份该安装；确认原始来源后再选择覆盖命令。")
         ("reason.prune-evidence" "installation evidence is incomplete or invalid; package is protected from pruning" "安装证据不完整或无效；已保护该应用，不自动清理")
         ("error.maintenance-diagnostics" "[hub] maintenance blocked before changes:
{details}" "[hub] 已在修改前停止维护操作：
{details}")
         ("status.verified" "verified" "已验证")
         ("status.unverified" "unverified" "未验证")
         ("status.invalid" "invalid" "无效")
         ("label.scope" "scope" "范围")
         ("label.query" "query" "查询")
         ("label.index" "index" "索引")
         ("label.latest" "latest" "最新版本")
         ("label.versions" "versions" "版本")
         ("label.name" "name" "名称")
         ("label.kind" "kind" "类型")
         ("label.version" "version" "版本")
         ("label.release" "release" "发行序号")
         ("label.version-id" "version id" "版本标识")
         ("label.tag" "tag" "标签")
         ("label.license" "license" "许可证")
         ("label.command" "command" "命令")
         ("label.repository" "repository" "仓库")
         ("label.repo-slug" "repo slug" "仓库标识")
         ("label.runtime" "runtime" "运行时")
         ("label.main" "main" "主文件")
         ("label.help" "help" "帮助")
         ("label.dockerfile" "dockerfile" "Dockerfile")
         ("label.container" "container" "容器")
         ("label.image-tag" "image tag" "镜像标签")
         ("label.digest" "digest" "摘要")
         ("label.platforms" "platforms" "平台")
         ("label.smoke" "smoke" "冒烟测试")
         ("label.smoke-exist" "smoke exist" "存在检查")
         ("label.smoke-test" "smoke test" "命令测试")
         ("label.source-ref" "source ref" "源码引用")
         ("label.source-commit" "source commit" "源码提交")
         ("label.source-url" "source url" "源码地址")
         ("label.action" "action" "操作")
         ("label.alias" "alias" "别名")
         ("label.app" "app" "应用")
         ("label.bin" "bin" "命令目录")
         ("label.deps" "deps" "依赖")
         ("label.path" "path" "路径")
         ("label.ref" "ref" "引用")
         ("label.resolved-source" "resolved source" "解析后来源")
         ("label.source" "source" "来源")
         ("label.current" "current" "当前文件")
         ("label.snapshot" "snapshot" "快照")
         ("label.bytes" "bytes" "字节数")
         ("label.home" "home" "主目录")
         ("label.metadata" "metadata" "元数据")
         ("label.origin" "origin" "来源类型")
         ("label.found" "found" "总数")
         ("label.showing" "showing" "显示")
         ("label.image" "image" "镜像")
         ("label.repo" "repo" "仓库")
         ("label.images" "images" "镜像")
         ("label.reason" "reason" "原因")
         ("label.hint" "hint" "提示")
         ("label.exists" "exists" "存在状态")
         ("label.dry-run" "dry-run" "试运行")
         ("label.install" "install" "安装")
         ("label.installable" "installable" "可安装")
         ("label.outdated" "outdated" "可升级")
         ("label.prunable" "prunable" "可清理")
         ("label.upgrade" "upgrade" "升级")
         ("label.remove" "remove" "删除")
         ("label.installed" "installed" "已安装")
         ("label.prune" "prune" "清理")
         ("label.command-file" "command file" "命令文件")
         ("label.launcher" "launcher" "启动器")
         ("update.header" "[TAF] updated TAFFISH index" "[TAF] 已更新 TAFFISH 索引")
         ("info.header" "[TAF] app info: {name}" "[TAF] 应用信息：{name}")
         ("search.header" "[TAF] search: {query}" "[TAF] 搜索：{query}")
         ("search.no-matches" "  no matches" "  没有匹配结果")
         ("search.item.image" "image" "镜像")
         ("search.item.repo" "repo" "仓库")
         ("list.header.indexed" "[TAF] indexed apps" "[TAF] 索引中的应用")
         ("list.header.installed" "[TAF] installed apps" "[TAF] 已安装应用")
         ("list.no-apps" "  no apps" "  没有应用")
         ("which.header" "[TAF] which: {artifact}" "[TAF] 本地定位：{artifact}")
         ("install.cloning"
          "[TAF] cloning source: {source} ({ref})"
          "[TAF] 正在克隆源码：{source}（{ref}）")
         ("install.copying"
          "[TAF] copying local source: {source}"
          "[TAF] 正在复制本地源码：{source}")
         ("install.header"
          "[TAF] {action}: {app} {version}"
          "[TAF] {action}：{app} {version}")
         ("install.batch"
          "[TAF] install batch summary: {count} target(s)"
          "[TAF] 批量安装摘要：{count} 个目标")
         ("install.batch-counts"
          "  installed/skipped : {installed}/{skipped}"
          "  已安装/已跳过      : {installed}/{skipped}")
         ("install.apply-hint"
          "rerun without --dry-run to install"
          "不带 --dry-run 重新运行以执行安装")
         ("uninstall.skipped"
          "[TAF] uninstall skipped: {query}"
          "[TAF] 已跳过卸载：{query}")
         ("uninstall.header"
          "[TAF] {action}: {app} {version}"
          "[TAF] {action}：{app} {version}")
         ("uninstall.batch"
          "[TAF] uninstall batch summary: {count} target(s)"
          "[TAF] 批量卸载摘要：{count} 个目标")
         ("uninstall.batch-counts"
          "  uninstalled/skipped : {uninstalled}/{skipped}"
          "  已卸载/已跳过        : {uninstalled}/{skipped}")
         ("uninstall.not-installed" "not installed" "尚未安装")
         ("uninstall.images-kept" "kept" "保留")
         ("uninstall.apply-hint"
          "rerun without --dry-run to uninstall"
          "不带 --dry-run 重新运行以执行卸载")
         ("batch.commands" "  commands            : {commands}" "  命令                 : {commands}")
         ("upgrade.header"
          "[TAF] {operation} {mode}"
          "[TAF] {operation}{mode}")
         ("upgrade.mode.plan" "plan" "计划")
         ("upgrade.mode.result" "result" "结果")
         ("upgrade.no-changes" "  no changes" "  没有需要变更的应用")
         ("upgrade.no-apps" "  no apps" "  没有应用")
         ("upgrade.prune-summary"
          "{count} package group(s) had old versions removed"
          "已从 {count} 个软件包组中删除旧版本")
         ("upgrade.apply-hint"
          "rerun with --yes to apply"
          "使用 --yes 重新运行以应用变更")
         ("info.runtime"
          "pipe={pipe}, command-mode={command-mode}"
          "管道={pipe}，命令模式={command-mode}")
         ("info.smoke"
          "{backend}, timeout={timeout}, exist={exist}, test={test}"
          "{backend}，超时={timeout}，存在检查={exist}，命令测试={test}")
         ("which.exists"
          "launcher={launcher}, command={command}, app={app}, source={source}"
          "启动器={launcher}，命令={command}，应用={app}，源码={source}")
         ("value.unknown" "<unknown>" "<未知>")
         ("value.none" "<none>" "<无>")
         ("value.ok" "ok" "正常")
         ("value.not-in-path" "not in PATH" "不在 PATH 中")
         ("reason.target-not-installed"
          "target is not installed"
          "目标尚未安装")
         ("reason.indexed-not-installed"
          "package is indexed but not installed"
          "软件包已收录于索引，但尚未安装")
         ("reason.local-older"
          "local version is older than index latest"
          "本地版本早于索引中的最新版本")
         ("reason.local-current"
          "local latest matches index latest"
          "本地最新版本与索引最新版本一致")
         ("reason.local-ahead"
          "local latest is newer than index latest"
          "本地最新版本高于索引最新版本")
         ("reason.missing-index"
          "installed package is not present in local index"
          "已安装软件包不在本地索引中")
         ("reason.local-project"
          "local-project install is private and is not upgraded from the public index"
          "本地项目安装属于私有来源，不会从公共索引升级")
         ("reason.old-versions"
          "older locally installed versions can be removed"
          "可以删除本地安装的旧版本")
         ("reason.single-version"
          "only one local version is installed"
          "本地仅安装了一个版本")
         ("reason.latest-unusable"
          "no usable index latest or matching install source"
          "没有有效的 index.latest，或安装来源与索引不一致")
         ("reason.prune-private"
          "local-project versions are protected from index pruning"
          "本地私有项目版本不会按公共索引自动清理")
         ("reason.prune-unusable"
          "index latest is not a valid same-source installation; nothing is removed"
          "index.latest 尚未有效安装或来源不一致；不删除任何版本")
         ("reason.prune-old"
          "older same-source versions can be removed; index latest is retained"
          "可以清理同源旧版本；保留 index.latest")
         ("reason.prune-protected"
          "no safely removable versions; index latest and protected versions are retained"
          "没有可安全清理的旧版本；保留 index.latest 及受保护版本")
         ("error.maintenance-order"
          "[hub] cannot safely order {local} against index latest {latest}; use an explicit version install instead."
          "[hub] 无法可靠比较本地 {local} 与 index.latest {latest}；请显式指定版本安装。")
         ("error.maintenance-invalid"
          "[hub] installed index latest {version} failed validation; reinstall that exact version with --force before maintenance."
          "[hub] 已安装的 index.latest {version} 未通过验证；请先用 --force 重装该指定版本。")
         ("error.target-invalid"
          "[{command}] invalid target: {target}"
          "[{command}] 无效目标：{target}")
         ("error.target-missing"
          "[{command}] app name or command name missing."
          "[{command}] 缺少应用名称或命令名称。")
         ("error.index-missing"
          "[{command}] local TAFFISH index does not exist: {path}
Run `taf update` first."
          "[{command}] 本地 TAFFISH 索引不存在：{path}
请先运行 `taf update`。")
         ("error.index-not-object"
          "[{command}] local TAFFISH index is not a JSON object: {path}"
          "[{command}] 本地 TAFFISH 索引不是 JSON 对象：{path}")
         ("error.index-schema"
          "[{command}] unsupported TAFFISH index schema: {schema}"
          "[{command}] 不支持的 TAFFISH 索引 schema：{schema}")
         ("error.index-missing-object"
          "[{command}] index is missing object field: {field}"
          "[{command}] 索引缺少对象字段：{field}")
         ("error.command-entry"
          "[{command}] command entry is not an object: {query}"
          "[{command}] 命令条目不是对象：{query}")
         ("error.not-found"
          "[{command}] can't find TAFFISH app or command in local index: {query}"
          "[{command}] 无法在本地索引中找到 TAFFISH 应用或命令：{query}")
         ("error.package-entry"
          "[{command}] package entry is not an object: {package}"
          "[{command}] 软件包条目不是对象：{package}")
         ("error.exact-version-conflict"
          "[{command}] exact command {query} already contains version {exact}, but VERSION-ID is {requested}."
          "[{command}] 精确命令 {query} 已包含版本 {exact}，但 VERSION-ID 为 {requested}。")
         ("error.package-no-versions"
          "[{command}] package has no versions object: {package}"
          "[{command}] 软件包缺少 versions 对象：{package}")
         ("error.package-no-latest"
          "[{command}] package has no latest version: {package}"
          "[{command}] 软件包缺少 latest 版本：{package}")
         ("error.package-version-missing"
          "[{command}] package {package} has no version {version}.
Available versions: {available}"
          "[{command}] 软件包 {package} 不包含版本 {version}。
可用版本：{available}")
         ("error.version-record"
          "[{command}] version record is not an object: {package} {version}"
          "[{command}] 版本记录不是对象：{package} {version}")
         ("error.keyword-missing"
          "[search] keyword missing."
          "[search] 缺少搜索关键词。")
         ("error.update-local-missing"
          "[update] local index file does not exist: {path}"
          "[update] 本地索引文件不存在：{path}")
         ("error.update-no-curl"
          "[update] can't find curl executable for downloading: {url}"
          "[update] 找不到用于下载的 curl 可执行程序：{url}")
         ("error.update-download"
          "[update] failed to download index from {url}.
{detail}
This is usually a network/proxy problem when accessing the index URL. You can retry later or use `taf update --url <INDEX-URL>` / TAFFISH_INDEX_URL."
          "[update] 无法从 {url} 下载索引。
{detail}
这通常是访问索引地址时的网络或代理问题。请稍后重试，或使用 `taf update --url <INDEX-URL>` / TAFFISH_INDEX_URL。")
         ("error.update-source"
          "[update] index source must be a local file or http(s) URL, but got: {source}"
          "[update] 索引来源必须是本地文件或 http(s) URL，实际收到：{source}")
         ("error.update-empty"
          "[update] downloaded index is empty: {source}"
          "[update] 下载的索引为空：{source}")
         ("error.update-invalid"
          "[update] downloaded file does not look like a TAFFISH index: {source}"
          "[update] 下载的文件不像 TAFFISH 索引：{source}")
         ("error.install-non-empty"
          "[install] {label} must be a non-empty string."
          "[install] {label} 必须是非空字符串。")
         ("error.install-path-separator"
          "[install] {label} must not contain path separators: {value}"
          "[install] {label} 不能包含路径分隔符：{value}")
         ("error.install-record-command"
          "[install] version record is missing command object."
          "[install] 版本记录缺少 command 对象。")
         ("error.install-record-command-name"
          "[install] version record is missing command.name."
          "[install] 版本记录缺少 command.name。")
         ("error.install-record-version"
          "[install] version record must contain version and release."
          "[install] 版本记录必须包含 version 与 release。")
         ("error.install-clone"
          "[install] git clone failed ({code}): git {command}
{detail}"
          "[install] git clone 失败（{code}）：git {command}
{detail}")
         ("error.install-local-source"
          "[install] local source directory does not exist: {source}"
          "[install] 本地源码目录不存在：{source}")
         ("error.install-source"
          "[install] source must be a Git URL or local directory, but got: {source}"
          "[install] 来源必须是 Git URL 或本地目录，实际收到：{source}")
         ("error.install-inspect-commit"
          "[install] failed to inspect installed source commit in {source}.
{detail}"
          "[install] 无法检查 {source} 中已安装源码的提交。
{detail}")
         ("error.install-inspect-status"
          "[install] failed to inspect installed source status in {source}.
{detail}"
          "[install] 无法检查 {source} 中已安装源码的状态。
{detail}")
         ("error.install-commit-mismatch"
          "[install] source commit mismatch.
  source  : {source}
  ref     : {ref}
  expected: {expected}
  got     : {actual}"
          "[install] 源码提交不匹配。
  来源    ：{source}
  引用    ：{ref}
  预期    ：{expected}
  实际    ：{actual}")
         ("error.install-dirty"
          "[install] source commit matches, but source worktree is not clean.
  source: {source}
  ref   : {ref}
  status:
{status}"
          "[install] 源码提交匹配，但源码工作区不干净。
  来源  ：{source}
  引用  ：{ref}
  状态：
{status}")
         ("error.install-already"
          "[install] app version is already installed: {path}
Use --force to reinstall."
          "[install] 应用版本已经安装：{path}
请使用 --force 重新安装。")
         ("error.install-command-exists"
          "[install] command already exists: {path}
Use --force to replace it."
          "[install] 命令已经存在：{path}
请使用 --force 替换。")
         ("error.install-dependency-string"
          "[install] dependency version must be a string, but got: {value}"
          "[install] 依赖版本必须是字符串，实际收到：{value}")
         ("error.install-dependency-empty"
          "[install] dependency version array must not be empty."
          "[install] 依赖版本数组不能为空。")
         ("error.install-dependencies-object"
          "[install] version record dependencies must be an object."
          "[install] 版本记录中的 dependencies 必须是对象。")
         ("error.install-no-source"
          "[install] version record has no repository/source URL."
          "[install] 版本记录缺少 repository/source URL。")
         ("error.install-circular"
          "[install] circular dependency detected: {chain} -> {package}"
          "[install] 检测到循环依赖：{chain} -> {package}")
         ("error.install-command-mismatch"
          "[install] built command does not match index.
  expected: {expected}
  got     : {actual}"
          "[install] 构建命令与索引不一致。
  预期：{expected}
  实际：{actual}")
         ("error.installed-missing"
          "[{command}] app version is not installed: {query}{version}"
          "[{command}] 应用版本尚未安装：{query}{version}")
         ("error.installed-multiple"
          "[{command}] multiple installed versions match {query}. Specify VERSION-ID.
Candidates: {candidates}"
          "[{command}] 多个已安装版本匹配 {query}，请指定 VERSION-ID。
候选版本：{candidates}")
         ("error.upgrade-kind"
          "[{command}] kind must be tool, flow, or all, but got: {value}"
          "[{command}] kind 必须是 tool、flow 或 all，实际收到：{value}")
         ("error.list-mode"
          "[list] mode must be :local or :online, but got: {value}"
          "[list] mode 必须是 :local 或 :online，实际收到：{value}")
	         ("error.list-limit"
	          "[list] limit must be a positive integer, but got: {value}"
	          "[list] limit 必须是正整数，实际收到：{value}")
         ("status.install" "install" "安装")
         ("status.install-dry-run" "install dry-run" "安装试运行")
         ("status.install-latest" "install latest" "安装最新版本")
         ("status.installed" "installed" "已安装")
         ("status.uninstall" "uninstall" "卸载")
         ("status.uninstall-dry-run" "uninstall dry-run" "卸载试运行")
         ("status.uninstalled" "uninstalled" "已卸载")
         ("status.skip" "skip" "跳过")
         ("status.skipped" "skipped" "已跳过")
         ("status.outdated" "outdated" "可升级")
         ("status.current" "current" "已是最新")
         ("status.ahead" "ahead" "本地版本较新")
         ("status.upgrade" "upgrade" "升级")
         ("status.prune" "prune" "清理")
         ("status.remove-old" "remove old" "删除旧版本")
         ("status.install-all" "install-all" "批量安装")
         ("status.missing-index" "missing index" "索引中缺失")
         ("status.local-project" "local project" "本地项目")
         ("status.not-installed" "not installed" "尚未安装")
         ("status.dry-run" "dry-run" "试运行")
         ("status.yes" "yes" "是")
         ("status.no" "no" "否")))
    (destructuring-bind (suffix english chinese) entry
      (taffish.i18n:register-message
       (format nil "taf.hub.~A" suffix)
       english chinese))))

(%register-hub-i18n-messages)

(defun %hub-message (suffix &rest bindings)
  (apply #'taffish.i18n:message-with
         (format nil "taf.hub.~A" suffix)
         bindings))

(defun %hub-print-message (suffix &rest bindings)
  (format t "~A~%" (apply #'%hub-message suffix bindings)))

(defun %hub-repr (value)
  (prin1-to-string value))

(defun %hub-error (suffix &rest bindings)
  (error "~A" (apply #'%hub-message
                      (format nil "error.~A" suffix)
                      bindings)))

(defun %hub-label (label)
  (let* ((suffix (format nil "label.~A"
                         (substitute #\- #\Space
                                     (string-downcase label))))
         (key (format nil "taf.hub.~A" suffix))
         (translated (%hub-message suffix)))
    (if (string= translated key)
        label
        translated)))

(defun %hub-status-display (status)
  (let* ((value (string-downcase (string status)))
         (key (format nil "status.~A" value))
         (translated (%hub-message key)))
    (if (string= translated (format nil "taf.hub.~A" key))
        value
        translated)))

(defun %hub-reason-display (reason)
  (if (null reason)
      nil
      (let ((suffix
          (cond
            ((string= reason "target is not installed")
             "reason.target-not-installed")
            ((string= reason "package is indexed but not installed")
             "reason.indexed-not-installed")
            ((string= reason "local version is older than index latest")
             "reason.local-older")
            ((string= reason "local latest matches index latest")
             "reason.local-current")
            ((string= reason "local latest is newer than index latest")
             "reason.local-ahead")
            ((string= reason "installed package is not present in local index")
             "reason.missing-index")
            ((string= reason
                      "local-project install is private and is not upgraded from the public index")
             "reason.local-project")
            ((string= reason "older locally installed versions can be removed")
             "reason.old-versions")
            ((string= reason "only one local version is installed")
             "reason.single-version")
            ((string= reason "no usable index latest or matching install source")
             "reason.latest-unusable")
            ((string= reason "local-project versions are protected from index pruning")
             "reason.prune-private")
            ((string= reason "index latest is not a valid same-source installation; nothing is removed")
             "reason.prune-unusable")
            ((string= reason "older same-source versions can be removed; index latest is retained")
             "reason.prune-old")
            ((string= reason "no safely removable versions; index latest and protected versions are retained")
             "reason.prune-protected")
            ((string= reason "installation evidence is incomplete or invalid; package is protected from pruning")
             "reason.prune-evidence")
            (t nil))))
        (if suffix
            (%hub-message suffix)
            reason))))
