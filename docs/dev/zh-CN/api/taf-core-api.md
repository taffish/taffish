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

返回：

```lisp
(:project project :command command-result :image image-result)
```

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
                          :release-p nil
                          :remote-tags remote-tags
                          :commit-message message
                          :verbose t)
```

作用：发布项目到 GitHub。

默认 `dry-run t`，不会执行发布。

非 dry-run 副作用：

1. git init。
2. git remote add。
3. git add/commit/tag/push。
4. 可选 gh repo create。
5. 可选 gh release create。

安全说明：TAFFISH 不接管 GitHub 登录。认证必须由用户在外部完成。

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

安全说明：source URL 会通过 system config 的 rewrite 规则解析。安装会运行 git 和 build 逻辑。

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

### `taf.core:system-doctor`

稳定性：稳定。

作用：检查目录、可执行程序、PATH 状态。

副作用：`init-p t` 时创建缺失目录。system scope init 需要 root。

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
| `hub-uninstall` | 删除安装目录和 launcher。 |
| `system-config-init` | 写 config。 |
| `system-doctor :init-p t` | 创建目录。 |
| `system-history :clear-p t` | 删除 history。 |

新代码调用这些 API 时，应明确是否允许副作用，并优先提供 dry-run 或 verbose 控制。
