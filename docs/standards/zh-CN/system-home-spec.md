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
