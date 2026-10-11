# taf-core API

`taf-core` 是 `taf` 命令背后的业务 API。它覆盖项目、hub、系统三类能力，其中不少函数会读写文件、运行外部命令、操作 git 或安装 app。

## 默认值变量

稳定性：半稳定。

| 变量 | 说明 |
| --- | --- |
| `*default-github-host*` | 默认 GitHub host，当前 `github.com`。 |
| `*default-github-owner*` | 默认 GitHub owner，当前 `taffish`。 |
| `*default-container-registry*` | 默认容器 registry，当前 `ghcr.io`。 |
| `*default-docker-base-image*` | `taf new --docker` 的默认 base image。 |
| `*default-index-repository*` | 默认 index repository。 |
| `*default-index-branch*` | 默认 index branch。 |

这些变量影响默认 repo、image、index URL。修改会影响新项目和 hub 默认行为。

## Project API

### `taf.core:project-new`

稳定性：稳定。

```lisp
(taf.core:project-new name args)
```

作用：创建 taf-app 项目骨架。

副作用：创建目录和文件。

返回：当前主要通过 stdout 报告结果，返回值不作为稳定契约。

常见错误：

1. project name 非法。
2. 目标目录已存在。
3. version/release/license/repo 非法。

### `taf.core:project-check`

稳定性：稳定。

```lisp
(taf.core:project-check &optional start-dir verbose dependency-check-p)
```

作用：查找项目根、读取 `taffish.toml`、检查 main TAF、返回 project plist。

返回字段包括：

```text
:root-dir :toml-file :name :kind :version :release :license
:repository-url :command-name :main-path :main-file :help-file
:target-dir :runtime-pipe :runtime-command-mode :container-image
:dependencies :smoke :dockerfile :container-build-platforms
```

副作用：默认 verbose 时打印摘要，不修改文件。

### `taf.core:project-compile`

稳定性：稳定。

```lisp
(taf.core:project-compile &optional args start-dir &rest options)
```

作用：编译项目 main TAF，返回 shell string。

支持 option：

```lisp
:container-backend
```

副作用：无文件写入，但会探测外部命令和 CPU 数。

### `taf.core:project-run`

稳定性：稳定。

```lisp
(taf.core:project-run :args args
                      :start-dir start-dir
                      :container-backend backend
                      :input input
                      :output output
                      :error-output error-output)
```

作用：编译项目 TAF 到临时 shell 并运行。

副作用：创建并清理临时目录，执行 shell。

返回：

```lisp
(:exit-code code :stdout stdout :stderr stderr)
```

### `taf.core:project-build`

稳定性：稳定。

```lisp
(taf.core:project-build :command-p t
                        :image-p nil
                        :backend backend
                        :user-home user-home
                        :system-home system-home
                        :start-dir start-dir
                        :verbose t)
```

作用：构建 command wrapper 和可选 container image。

副作用：

1. 写入 `target/`。
2. 复制 source snapshot。
3. chmod wrapper。
4. 对 flow 项目可能重写 `[dependencies]`。
5. `:image-p t` 时运行 Docker 或 Podman build。

command-wrapper 产物通过私有 build manifest 建立内容身份。未变化且有效的
wrapper/snapshot 会直接返回，不重写两项产物；重建替换通过 staging 完成，失败时恢复
最后一个有效产物对。

返回：

```lisp
(:project project :command command-result :image image-result)
```

command plist 保留原有字段，并以 additive 方式报告 `:status`、`:source-sha256`、
`:wrapper-sha256` 与 `:manifest-file`。

### `taf.core:project-publish`

稳定性：半稳定。

```lisp
(taf.core:project-publish :start-dir start-dir
                          :dry-run t
                          :build-p nil
                          :channel :latest
                          :prompt-p nil
                          :create-repo-p nil
                          :repo-visibility :public
                          :lock-repo-p t
                          :release-p nil
                          :remote-tags remote-tags
                          :commit-message message
                          :verbose t)
```

作用：发布项目到 GitHub。

默认 `dry-run t`，不会执行发布。

发布不要求当前版本高于历史版本。`:release-p t` 时，`:channel :latest`（默认）
创建正式 GitHub Release 并标记为 Latest；`:pre` 创建 GitHub prerelease 且不设置
Latest；`:no-latest` 创建正式 Release 但不设置 Latest。`:release-p nil` 仍然只发布 tag。

非 dry-run 副作用：

1. git init。
2. git remote add。
3. git add/commit/tag/push。
4. 可选 gh repo create。
5. 可选 gh release create。
6. 在 TAFFISH user home 下写入 publish journal。

安全说明：TAFFISH 不接管 GitHub 登录。认证必须由用户在外部完成。

发布内部使用 inspect/ensure 状态机。中断后使用相同参数再次调用会继续匹配的半完成
发布；commit、tag、repository、policy 或 Release 身份冲突时会停止且不覆盖。返回值
保留旧字段，并增加 `:outcome`、`:phases`、`:resumed-p`、`:complete-p`、
`:journal-file`、`:warnings` 与 `:build-status`。`:build-p t` 时会在 commit 前确保
build；匹配的发布 commit/tag 身份建立后会跳过重建。

续跑必须保持相同渠道与 Release 意图。已有匹配 Release 不会被修改，也不会从后续发布
抢回 Latest。旧返回字段 `:remote-latest` 仅是远端 tag 排序诊断，不代表 GitHub Latest，
也不用于决定是否允许发布。

## Hub API

### `taf.core:hub-update`

稳定性：稳定。

作用：下载或读取 index，写入 `index/current.json` 和 snapshot。

副作用：写 index 文件，可能访问网络或读取本地文件。

返回：包含 `:scope`、`:home`、`:source`、`:current-file`、`:snapshot-file`、`:timestamp`、`:bytes` 的 plist。

### `taf.core:hub-info` / `hub-info-many`

稳定性：稳定。

作用：从本地 index 解析 package、command 或 artifact query。

副作用：默认 verbose 时打印结果，不修改文件。

返回：解析结果 plist，包含 `:package-name`、`:version-id`、`:record` 等。

### `taf.core:hub-search`

稳定性：稳定。

作用：搜索本地 index。

返回：包含 `:query`、`:terms`、`:total`、`:matches` 的 plist。

### `taf.core:hub-install` / `hub-install-many`

稳定性：稳定。

作用：安装 hub app。

副作用：

1. clone 或复制 source。
2. 调用 `project-build`。
3. 写 install root。
4. 写 launcher。
5. 写 install metadata。
6. 递归安装依赖。

支持 `dry-run-p`。dry-run 不应写文件。

可选 `:repair-p` 默认为 `nil`。为 `t` 时，先对全部选中对象只读预检，仅重建来源、身份、
受管理路径及固定源码 commit 均通过修复检查的已有索引身份。verified 目标跳过；任一
blocked 目标阻断整批写入。显式目标缺失、未知 schema、私有来源及自定义 launcher 均受阻。
repair 不递归安装依赖，拒绝 `:force-p`；单项 API 的 repair 模式也拒绝调用方提供
`:record`。用 `:dry-run-p t` 预览，否则显式单项/多项 repair 会执行。
opt-in 返回 `taffish.repair-plan/v1`，普通调用的返回结果不变。暂存、备份、验证、回滚和
中断 journal 限制见[修复策略](../taf-core/hub-maintenance.md#显式修复)。不新增 MCP
repair 参数或执行入口。

安全说明：source URL 会通过 system config 的 rewrite 规则解析。安装会运行 git 和 build 逻辑。

### `taf.core:hub-install-all`

稳定性：稳定。

作用：按 kind 过滤后计划或安装 index 中的所有 app。

副作用：当 `yes-p` 为真时，对每个 package 执行和 `hub-install` 相同的安装副作用。

支持 `dry-run-p`；CLI 和 MCP planner 层默认应使用 dry-run。可选的 `prune-old-p`
只会在非 dry-run 且安装成功后移除本地旧版本。

默认情况下，`:repair-p t` 仅选择 `:kind`、`:scope` 范围内已安装的 index.latest 身份。
确实不存在的身份计数后跳过，已有目录但元数据损坏时受阻。不升级其他版本、不新装
app/依赖。一个旧身份可通过 `hub-install` 的显式 `:version-id` 指定；全部已安装版本
则使用 `:all-installed-p t`。repair 拒绝
`:force-p`、`:prune-old-p`；只有 `:yes-p t` 且 `:dry-run-p nil` 才执行，否则预览。
整批预检及 `taffish.repair-plan/v1` 返回契约与上文一致。

`:all-installed-p` 默认为 `nil`，必须配合 `:repair-p t`。为真时从本地全部已安装版本
选择目标，而非 index.latest；缺失或无法解析的记录保持受阻。类型/作用域筛选、
预览/yes 和既有安全预检仍适用。修复结果新增 `selection`：`index-latest`、
`installed-all-versions` 或 `explicit`；已有字段和普通安装结果不变。

### `taf.core:hub-outdated`

稳定性：稳定。

作用：把本地 install metadata 和本地 index 进行比较，报告 outdated、current、
ahead、missing-index、local-project 或 not-installed 状态。

副作用：默认 verbose 时打印，不修改文件。

### `taf.core:hub-upgrade`

稳定性：稳定。

作用：计划或安装本地已安装 app 的 index latest 版本。

副作用：当 `yes-p` 为真时，对 outdated package 执行和 `hub-install` 相同的安装副作用。
本地/私有 `local-project` 安装会被跳过。

支持 `dry-run-p`；dry-run 不应写文件。

### `taf.core:hub-prune`

稳定性：稳定。

作用：保留已安装且有效的 index.latest，只移除可靠地更旧的同源版本。
缺失或无效目标跳过；私有/未知/冲突来源、较新或顺序不明确的身份受到保护。

副作用：

1. 删除旧 install root。
2. 删除旧 artifact launcher。
3. 刷新不带版本号的 command alias。

支持 `dry-run-p`。它不会删除 Docker/Podman/Apptainer 镜像、Apptainer cache
或 SIF 文件。

### Package Maintenance 输出

普通 `hub-install-all`（不带 repair）、`hub-outdated`、`hub-upgrade` 和 `hub-prune` 返回或打印同一类
package-plan 结构。JSON 输出保留每个 item。默认文本只隐藏状态正常且无需变更的项，
仍显示验证警告、缺少目标或来源不匹配等问题。版本已是 current 不代表完整性已验证。
没有需要呈现的变更、警告或阻塞时报告 `no changes`。

重复诊断在作用域内按问题类型/状态和策略汇总，含计数及每组至多三个例子，不重复 skip 行；
完整结构化证据仍保留。人类 stderr 进度在 TTY 原地显示阶段/计数，在日志中限频逐行输出。
`:verbose nil`、JSON、MCP 无进度文字；探测缓存仅限同一次只读扫描，不跨变更复用。

在线目标遵循 index.latest，不重新求本地最大值。精确目标已有效安装时为 current，
即使还有更高的本地版本；维护不会自动降级。详见 [Hub 版本策略](../taf-core/hub-system.md#版本选择与安全清理)。

### `taf.core:hub-uninstall` / `hub-uninstall-many`

稳定性：稳定。

作用：卸载本地 app。

副作用：

1. 删除 install root。
2. 删除 artifact launcher。
3. 删除或刷新 command alias。

支持 `dry-run-p`。

### `taf.core:hub-list`

稳定性：稳定。

作用：列出本地安装或本地 index 内容。

mode：

```text
:local / :installed
:online / :index
```

支持 JSON 输出，JSON schema 为 `taffish.list/v1`。

### `taf.core:hub-which` / `hub-which-many`

稳定性：稳定。

作用：定位已安装 app 的 launcher、command file、source、metadata 等路径。

支持 JSON 输出，JSON schema 为 `taffish.which/v1`。

## System API

### `taf.core:system-config`

稳定性：稳定。

作用：返回当前有效配置、home、bin、index、images、cache 等路径。

副作用：默认 verbose 时打印，不写文件。

### `taf.core:system-config-path`

稳定性：稳定。

作用：返回 active/user/system/explicit config 文件路径。

### `taf.core:system-config-init`

稳定性：稳定。

作用：写入 config template。

副作用：创建或覆盖 config 文件。system scope 需要 root。

profile：

```text
:github
:china
```

### `taf.core:system-config-language`

稳定性：增量公开接口。

作用：查看 configured/displayed language 和可用内置/外部语言包，或更新目标 scope 的顶层
`language` 字段。

副作用：`:language` 为 nil 时只读；否则在保留所有非 language config 文本的同时写入目标
配置文件。system scope 需要 root。外部语言 ID 必须存在于当前发现结果中。

### `taf.core:system-doctor`

稳定性：稳定。

作用：返回兼容的目录、executable、PATH 检查，并增加 config、index、command
path、shell completion、Vim/Neovim、Apptainer SIF 策略和有时间上限的
container backend readiness 结构化诊断。

新增可选参数：

```lisp
:shell :auto|:bash|:zsh|:fish
:detail-p boolean
:json-p boolean
:check :environment|:index|:hub
:targets list-of-strings
```

result 保留 `:status`、`:directories`、`:executables` 和 `:paths`，并新增
`:diagnostic-status` 与 `:diagnostics`。`:verbose` 控制渲染；JSON schema 为
`taffish.doctor/v1`。

Hub 默认文本按问题/策略限量摘要（每组至多三个例子）；`:detail-p t` 对应 CLI
`--verbose`，保留逐项完整检查。`:verbose` 控制是否渲染，而非证据完整性；返回 plist
及 JSON 保留全部诊断。Hub 使用批量只读探测，人类进度仅写 stderr，TTY 原地更新，日志
限频，JSON/MCP 不输出进度文字。

`:check` 默认 `:environment`。`:index` 和 `:hub` 为离线只读检查，增量返回
`:check`、`:exit-code` 及每项的 `:inspection` 证据。仅 `:hub` 接受应用/命令名
列表 `:targets`；专项检查拒绝 init 和非默认 shell 选择。退出码 1 表示 invalid/unknown，
0 包括警告。旧字段仍保留，未运行的默认环境检查组返回空列表。
详见 [doctor 契约](../taf-core/system-history-doctor.md)。

副作用：默认无副作用。只有 `init-p t` 时创建 TAFFISH 自己的缺失目录，system
scope init 需要 root。它不修改 shell/editor 配置或权限，不启动服务，不拉取镜像，
也不运行容器。

### `taf.core:system-history`

稳定性：稳定。

作用：查看、定位或清空 history JSONL。

副作用：`clear-p t` 时删除 history 文件。

### `taf.core:system-record-history-event`

稳定性：半稳定。

作用：追加 history event。

默认 `safe t`，写入失败返回 nil，不中断主流程。

## API 调用安全表

| API | 主要副作用 |
| --- | --- |
| `project-new` | 创建项目文件。 |
| `project-run` | 执行生成 shell。 |
| `project-build` | 写 target，可能 build image。 |
| `project-publish` | git/gh 发布操作。 |
| `hub-update` | 写 index，可能访问网络。 |
| `hub-install` | clone/copy/build/write launcher。 |
| `hub-install-all` | `yes-p` 为真时可能批量 clone/copy/build/write launcher。 |
| `hub-upgrade` | `yes-p` 为真时可能安装新版本 app。 |
| `hub-prune` | `yes-p` 为真时删除旧本地安装目录和 launcher。 |
| `hub-uninstall` | 删除安装目录和 launcher。 |
| `system-config-init` | 写 config。 |
| `system-config-language :language <value>` | 窄更新顶层 language 字段；system scope 需要 root。 |
| `system-doctor :init-p t` | 创建目录。 |
| `system-history :clear-p t` | 删除 history。 |

新代码调用这些 API 时，应明确是否允许副作用，并优先提供 dry-run 或 verbose 控制。
