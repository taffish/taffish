# TAFFISH Home 与系统布局规范

本页定义 TAFFISH 的用户级和系统级 home 目录布局。

## scope

TAFFISH 支持两个 scope：

| scope | 说明 |
| --- | --- |
| `user` | 当前用户安装和配置。 |
| `system` | 系统级安装和配置。 |

命令参数或内部 API 中的 `nil` 默认视为 `user`。

## home 路径

默认路径：

| 项 | 默认值 | 环境变量覆盖 |
| --- | --- | --- |
| user home | `$HOME/.local/share/taffish/` | `TAFFISH_USER_HOME` |
| system home | `/opt/taffish/` | `TAFFISH_SYSTEM_HOME` |
| system command bin | `/usr/local/bin/` | `TAFFISH_SYSTEM_BIN_DIR` |

路径应被规范化为目录路径，并保持尾部 slash 语义。

## 配置文件位置

每个 home 下的配置文件名固定为：

```text
config.toml
```

因此：

```text
<user-home>/config.toml
<system-home>/config.toml
```

`TAFFISH_CONFIG` 可以指定额外显式配置文件。配置合并顺序见 [TAFFISH 配置规范](system-config-spec.md)。

## 必需目录

`taf doctor --init` 应确保 active home 下存在以下目录：

```text
apps/
index/
index/snapshots/
images/
images/sif/
images/metadata/
images/locks/
images/tmp/
bin/
cache/
cache/repos/
cache/downloads/
cache/build/
share/
share/completions/
share/completions/bash/
share/completions/zsh/
share/completions/fish/
share/vim/
share/vim/syntax/
share/vim/ftdetect/
logs/
```

这些目录是 TAFFISH 本地状态的长期布局，不能随意改名。

## 共享 Apptainer SIF 缓存

`images/sif/` 用于保存生成 shell 自动拉取的 Apptainer SIF 文件。对于用户级 home，
这个目录通常只属于当前用户。

对于系统级 home，TAFFISH 不要求安装器把 `<system-home>/images/sif/` 自动设置为
所有用户可写。站点管理员应该明确选择策略：

| 策略 | 含义 |
| --- | --- |
| 用户级缓存 | 用户运行 `taf doctor --init --user`，SIF 文件保存到自己的用户级 home。 |
| 管理员预缓存 | root 先运行常用 app，让 SIF 在普通用户运行前已经存在于 system home。 |
| 共享可写缓存 | 管理员显式使用 `--system --shared-sif-cache` 安装（或只对准确 SIF 目录应用等价的 sticky `1777` 策略）。 |

共享可写缓存是站点策略决定。它不会被静默选择：普通 system 安装会为缺失的 SIF 目录
使用管理员管理的 `0755`，并保留已有目录的权限；只有显式 shared 策略才会把准确的
`<system-home>/images/sif/` 设置并验证为 `1777`。

## hub index 文件

当前 index 文件：

```text
<home>/index/current.json
```

快照文件：

```text
<home>/index/snapshots/index-<timestamp>.json
```

timestamp 来自 UTC 时间，安全文件名会去掉 `:` 和 `-`。

## app 安装布局

app 安装在：

```text
<home>/apps/<package-name>/<version-id>/
```

其中：

```text
source/
install.json
```

`source/` 保存 clone 或 copy 的 taf-app 源码。`install.json` 保存安装元数据，见 [TAFFISH 安装元数据规范](install-metadata-spec.md)。

## command bin

user scope 的 command bin：

```text
<user-home>/bin/
```

system scope 的 command bin：

```text
<system-bin-dir>/
```

安装时会写入：

1. versioned artifact launcher，例如 `taf-demo-v0.1.0-r1`。
2. command alias launcher，例如 `taf-demo`。

如果 command alias 对应多个版本，应指向最新的 version id。

## 权限要求

`system` scope 的初始化需要 root 权限。`taf doctor` 应检查目录是否存在、是否可写、command bin 是否在 `PATH` 中。

缺少目录但未传 `--init` 时，doctor 状态应为 `needs-init`。目录不可写时，状态应为 `permission-warning`。
