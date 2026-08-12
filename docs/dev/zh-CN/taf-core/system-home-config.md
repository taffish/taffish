# system/home 与 config

`system/home.lisp` 定义 TAFFISH 本地目录结构。`system/config.lisp` 定义配置文件、默认值、profile、index URL 和 source rewrite。

## system/home 的作用

home 层回答：

1. 用户级 TAFFISH home 在哪里。
2. 系统级 TAFFISH home 在哪里。
3. 系统级 bin 在哪里。
4. 某个 scope 应该使用哪个 home。
5. 哪些目录是必须存在的。
6. command bin 是否在 PATH 中。

## 默认目录

| 类型 | 默认 |
| --- | --- |
| system home | `/opt/taffish/` |
| system bin | `/usr/local/bin/` |
| user home | `$HOME/.local/share/taffish/` |

可用环境变量覆盖：

1. `TAFFISH_USER_HOME`
2. `TAFFISH_SYSTEM_HOME`
3. `TAFFISH_SYSTEM_BIN_DIR`

## 必需目录

TAFFISH home 下的必需目录包括：

```text
apps
index
index/snapshots
images
images/sif
images/metadata
images/locks
images/tmp
bin
cache
cache/repos
cache/downloads
cache/build
share
share/completions/bash
share/completions/zsh
share/completions/fish
share/vim/syntax
share/vim/ftdetect
logs
```

`doctor --init` 会创建这些目录。普通 `taf doctor` 保持只读，只报告缺失或
不可写路径，不会修改它们。

## scope

scope 只能是：

1. `:user`
2. `:system`

user scope 的 command bin 是 home 下的 `bin`。system scope 的 command bin 是 system bin。

## config schema

配置 schema：

```text
taffish.config/v1
```

默认配置：

| key | 默认 |
| --- | --- |
| `profile` | `github` |
| `language` | `auto` |
| `index-url` | GitHub raw index URL |
| `source-rewrite-rules` | nil |

`language` 字段由共享的 `taffish.i18n` 表现层读取。内置值是 `en` 和 `zh`；默认的 `auto`
选择会跟随主机 locale 并最终回退到英文，其他规范化 locale ID 可以选择可选外部语言包。
需要确定性人类输出时应显式保存 `en` 或 `zh`。`TAFFISH_LANGUAGE` 是优先级最高的单次
命令覆盖。

可选外部语言包位于 user/system home 下的 `share/locales/<locale>/`。它们不是必需目录，
`doctor --init` 不会创建或下载语言包。即使整个外部 locale tree 不存在，内置中英文仍可用。

`taf config language` 是只读发现与状态入口；`taf config language <LANGUAGE>` 更新 user
scope，增加 `--system` 后在 root 权限下更新 system scope。窄 writer 会保留所有非 language
配置行。外部 ID 只有在当前语言包有效且可发现时才允许写入。

## 配置文件加载顺序

有效配置从默认值开始，然后合并：

1. system config。
2. user config，仅 user scope。
3. `TAFFISH_CONFIG` 指定的显式 config。

后面的配置覆盖前面的配置。`config-files` 会记录实际加载的文件列表。

`taf doctor` 会把 effective config 解析纳入诊断。格式错误的 config 会以 error
和 remediation 报告，但 doctor 不会重写配置。doctor 也会检查 active home 下的
`index/current.json` 是否存在且可读，但不会下载 index。

## index URL 解析优先级

`%resolve-taffish-index-url` 使用：

1. 显式 URL。
2. `TAFFISH_INDEX_URL`。
3. `*taffish-index-default-url*`。
4. effective config 的 index URL。
5. default index URL。

## source rewrite

source rewrite 用于把 canonical source URL 改写到镜像源。

配置格式：

```toml
[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

这是服务中国用户的关键机制。注意 GitHub organization 是 `taffish`，Gitee organization 是 `taffish-org`。

## profile

`system-config-init` 支持：

| profile | 行为 |
| --- | --- |
| `github` | 使用 GitHub raw index，不设置 source rewrite。 |
| `china` | 使用 Gitee index，并把 GitHub source 改写到 Gitee。 |

system scope init 需要 root。

## 修改指南

修改 home/config 时要检查：

1. doctor 是否同步目录变化。
2. hub update/install 是否仍能解析 index/source。
3. Gitee/GitHub 镜像规则是否正确。
4. 新配置字段是否需要 schema 升级。
5. 环境变量优先级是否符合用户预期。
6. 语言变化是否保持机器 schema 和生成 shell 不变。
