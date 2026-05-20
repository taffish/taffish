# project/common 与 package

`taf-core/package.lisp` 定义 `taf.core` 的公开 API。`project/common.lisp` 则提供 project、hub、system 多处共享的默认值、命名规则、路径 helper 和项目根目录查找逻辑。

## 作用

这两个文件是 `taf-core` 的公共地基：

1. `package.lisp` 决定哪些能力对 CLI 或其他模块稳定可见。
2. `project/common.lisp` 决定默认 GitHub/GHCR/index 命名规则。
3. `project/common.lisp` 提供项目路径和项目根识别能力。

## 公开 API 分组

`taf.core` 当前导出：

| 类别 | API |
| --- | --- |
| 默认值 | `*default-github-host*`、`*default-github-owner*`、`*default-container-registry*`、`*default-docker-base-image*`、`*default-index-repository*`、`*default-index-branch*` |
| 项目 | `project-new`、`project-check`、`project-compile`、`project-build`、`project-run`、`project-publish` |
| hub | `hub-update`、`hub-search`、`hub-info`、`hub-info-many`、`hub-install`、`hub-install-from-project`、`hub-install-many`、`hub-install-all`、`hub-outdated`、`hub-upgrade`、`hub-prune`、`hub-uninstall`、`hub-uninstall-many`、`hub-list`、`hub-which`、`hub-which-many` |
| system | `system-config`、`system-config-path`、`system-config-init`、`system-doctor`、`system-history`、`system-record-history-event` |

## 默认命名规则

`project/common.lisp` 当前默认：

| 变量 | 默认值 |
| --- | --- |
| `*default-github-host*` | `github.com` |
| `*default-github-owner*` | `taffish` |
| `*default-container-registry*` | `ghcr.io` |
| `*default-docker-base-image*` | `debian:12-slim` |
| `*default-index-repository*` | `taffish-index` |
| `*default-index-branch*` | `main` |

注意：GitHub owner 是 `taffish`。Gitee 镜像 owner 是 `taffish-org`，它在 system config 的 china profile 中处理，不应把这两个概念混在 project 默认值里。

## 项目名称规则

项目名必须：

1. 是非空字符串。
2. 只包含 ASCII 字母、数字、`-`、`_`。
3. 不能以 `-` 或 `.` 开头。

这个规则影响 package name、repo URL、container image 和命令名，是 TAFFISH app 生态的基础约束。

## 默认派生值

`project/common.lisp` 会根据 project name、version、release 派生：

| 函数 | 结果 |
| --- | --- |
| `%default-repository-url` | `https://github.com/taffish/<name>` |
| `%default-container-image` | `ghcr.io/taffish/<name>:<version>-r<release>` |
| `%default-index-url` | GitHub raw index URL。 |

image name 会把 `_` 转成 `-` 并小写化。

## 项目根查找

`%find-project-root` 从当前目录向上寻找 `taffish.toml`。这是 `project-check`、`project-build`、`project-run` 等命令默认定位项目的基础。

## 修改指南

修改 common 层时要检查：

1. `taf new` 生成内容是否仍符合默认规则。
2. `taf check` 是否仍能识别旧项目。
3. hub index 中的 repository、command、artifact 命名是否受影响。
4. GitHub 与 Gitee 镜像配置是否仍保持边界清楚。
