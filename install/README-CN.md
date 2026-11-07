# TAFFISH 安装器

[English](README.md)

这个目录保存 TAFFISH 二进制 release 使用的 POSIX `sh` 安装器。

## 文件

- `install-taffish.template.sh`：唯一 canonical POSIX `sh` 实现。
- `generate-installers.sh`：生成并检查 provider-specific 脚本。
- `install-taffish.sh`：GitHub/默认 raw 安装器。
- `install-taffish.gitee.sh`：Gitee/中国地区 raw 安装器。

不要分别编辑两个生成脚本。修改模板后运行：

```sh
install/generate-installers.sh
install/generate-installers.sh --check
```

`--archive` / `--url` bundle 结构：

```text
target/
  taf-<os>-<arch>-<version>       （或旧布局 target/taf）
  taffish-<os>-<arch>-<version>   （或旧布局 target/taffish）
  taffish-mcp-<os>-<arch>-<version>
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
LICENSE
README.md
```

安装器会从 `target/` 自动选择当前主机匹配的二进制，并安装为
`$BIN_DIR/taf`、`$BIN_DIR/taffish` 和 `$BIN_DIR/taffish-mcp`。

默认校验模式是 `--verify auto`：

- 官方 GitHub/Gitee raw 安装必须在替换命令前，让每个选中二进制匹配
  `SHA256SUMS` 中唯一的条目；
- signed manifest、release key、`gpg` 和 `gpgv` 可用时，还会根据内置 TAFFISH
  release-key fingerprint 校验签名；
- 自定义来源在缺少 manifest 时仍可兼容使用，但会明确标记为 unverified；
- `--verify sha256` 和 `--verify gpg` 会强制对应等级，`--verify none` 是显式退出校验。

通过 `curl | sh` 获取的安装器脚本本身不会被 payload checksum 独立认证。高安全
bootstrap 应先从独立可信渠道获取并检查 fixed-tag 安装器，再在本地运行。二进制载荷
仍会在安装前完成上述校验。

## 安装后的语言

安装的命令内置英文（`en`）和中文（`zh`），无需单独安装语言包。没有已保存偏好时，
默认 `auto` 跟随可识别的系统 locale，并以英文兜底。独立 shell 安装脚本自身仍使用
英文提示。GitHub/Gitee 的选择以及 `github`/`china` 来源配置不决定语言。

将安装的命令加入 `PATH` 后：

```sh
taf config language          # 查看当前语言及可用语言
taf config language zh       # 为当前用户保存中文偏好
taf config language en       # 为当前用户保存英文偏好
taf config language auto     # 恢复跟随系统语言
TAFFISH_LANGUAGE=en taf -h   # 仅本次使用英文，不修改配置
```

该偏好也适用于 `taffish --help` 和 `taffish-mcp --help`，不改变生成的 shell 或 MCP
协议。管理员可用 `sudo taf config language zh --system` 设置系统默认值；用户偏好和
环境变量仍有更高优先级。普通重复安装保留已有配置；`--force-config` 会显式替换配置，
切换语言不需要使用它。外部语言包是可选能力，详见
[语言配置说明](../README-CN.md#cli-人类语言)。

## 依赖

安装器需要 macOS/Linux 的标准 POSIX 用户态，包括 `sh`、`tar`、`mktemp`、文件工具、
`awk`、`sed`、`grep`、`tr`、`stat` 和 `id`。官方载荷校验需要 `sha256sum` 或
`shasum`；在线来源需要 `curl` 或 `wget`。默认 `auto` 模式下，`gpg` 和 `gpgv` 是
可选签名增强；严格 `--verify gpg` 模式要求两者都存在。

## 默认路径和 scope

| Scope | 核心命令目录 | taf-app 命令目录 | TAFFISH home |
| --- | --- | --- | --- |
| user | `~/.local/bin` | `~/.local/share/taffish/bin` | `~/.local/share/taffish` |
| system | `/usr/local/bin` | `/usr/local/bin` | `/opt/taffish` |

安装器 scope 不会成为后续 CLI 的持久默认值。维护 system state 时仍要显式使用
`--system`：

```sh
sudo taf update --system
taf search --system fastqc
sudo taf install --system fastqc
taf list --system
```

user 安装需要把两个用户命令目录加入 `PATH`：

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
```

共享服务器使用 Apptainer 时，新建的 system SIF 目录采用管理员管理的 `0755`，已有
目录保留当前权限。普通安装不会把 cache 开放给所有用户写入。只有可信服务器确实需要
sticky shared cache 时才使用：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh \
  | sudo sh -s -- --system --shared-sif-cache
```

`--shared-sif-cache` 只把 `<TAFFISH_HOME>/images/sif` 设置并验证为准确的 `1777`，
不会递归修改 `/opt/taffish`。等价长形式为 `--sif-cache-policy shared`。

安装器识别以下环境变量：

```text
TAFFISH_USER_HOME
TAFFISH_SYSTEM_HOME
TAFFISH_SYSTEM_BIN_DIR
```

## 安装入口

GitHub user 安装：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

Gitee/中国地区 user 安装：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user
```

固定版本：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.11.0 --user
```

离线安装使用同一发布 tag 的安装脚本和原始 tar.gz 归档。按
[离线安装步骤](../README-CN.md#本地或离线安装)校验签名并跳过在线索引更新。

显式 bundle URL：

```sh
sh install/install-taffish.sh --user --url https://example.org/taffish.tar.gz
```

默认 raw 模式会从固定 `v<version>` tag 的 `target/` 下载三份版本化二进制，并从同一
tag 获取 completion 和 Vim 文件。可以通过 `--provider`、`--raw-base-url`、
`--share-url`、三个 binary URL 选项，以及 `--os` / `--arch` 明确覆盖来源或平台。

## 常用选项

```text
--user
--system
--prefix DIR
--bin-dir DIR
--taffish-home DIR
--provider github|gitee
--raw-base-url URL
--verify auto|sha256|gpg|none
--checksum-file FILE / --checksum-url URL
--signature-file FILE / --signature-url URL
--release-key-file FILE / --release-key-url URL
--retry COUNT
--connect-timeout SEC
--config-profile github|china|none
--force-config
--force
--sif-cache-policy auto|private|admin|shared
--shared-sif-cache
--dry-run
--os OS
--arch ARCH
--no-update
--no-doctor
```

`--dry-run` 会解析 scope、路径、provider、版本、校验和 SIF 策略，但不联网、不写文件。

安装器会在解包前检查 archive path 和 entry type；除非显式 `--force`，不会覆盖无关
核心命令；它还使用 home 级安装锁、候选二进制 `--version` smoke 和三命令事务替换。
替换失败会恢复旧二进制和安装收据。相同二进制不会被重复替换，但安装收据和 post-install
就绪检查仍可能执行。

成功后，`<TAFFISH_HOME>/install-receipt.toml` 会记录版本、scope、source kind、实际
校验等级、SIF 策略、asset 名和 SHA256，但不会保存 URL、token、密码或凭据。

默认会尝试运行 `taf update`。网络失败只会产生 warning，不会回滚已经校验并提交的核心
安装。system 安装的 post-install 使用明确的 system scope。

安装器不会修改 shell rc 或 Vim 配置，只会复制文件并输出其位置。参见
[completion 指南](../completion/README.md)和 [Vim 指南](../vim-highlight/README.md)。

## 测试安装器

仓库中存在当前平台的版本化二进制时运行：

```sh
./test/run-tests.sh --version 0.11.0 --filter installer/
```

十项测试覆盖测试夹具契约、模板漂移和 dry-run、checksum 与 GPG 校验、checksum 失败、危险 archive、
raw/custom URL、冲突与锁、事务回滚、post-install warning、幂等二进制替换和 SIF 权限。
测试只使用隔离临时目录和本地 fixture，不会访问 GitHub/Gitee，也不会写入真实 TAFFISH home。

独立 GPG 用例原样使用完整官方 manifest 和签名，搭配当前平台的二进制，验证严格和
自动模式的 GPG 成功路径，并检查篡改材料、错误公钥、严格模式缺失签名或公钥时拒绝安装。
失败不能修改新目标目录或已有安装。

该用例需要 `gpg`、`gpgv` 和与二进制匹配的正式签名材料。缺少工具或材料，或显式选择了
未签名的本地构建时，输出 `[SKIP]`、原因和独立计数；无效正式载荷必须失败，不能跳过。
发布前应要求 GPG 用例实际通过（全部跳过的运行返回失败）：

```sh
./test/run-tests.sh --version 0.11.0 --filter installer/gpg-verification
```

同时仍须独立验证最终 manifest 和签名。先决条件和覆盖边界详见
[外部测试指南](../test/README.md)。

不带后缀的本地构建可以显式选择：

```sh
./test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp \
  --filter installer/
```

普通用户运行会覆盖 user 安装和未授权 system 写入拒绝。管理员 `0755` 与 sticky `1777`
分支需要额外 root 测试，但仍只使用测试临时目录：

```sh
sudo ./test/run-tests.sh \
  --version 0.11.0 \
  --filter installer/system-permissions
```

installer 子集需要在 macOS 和 Linux 两个 release 平台运行；发布前还应运行不带 filter
的完整 delivered-binary 测试。

## 升级和移除

用相同 scope 和目标 `--version` 重新运行安装器，即可升级三个核心二进制。`taf upgrade`
只升级 taf-app。

当前没有专门的核心 uninstaller。手动移除前，应先卸载不再需要的 app、备份自定义
`config.toml`，并确认 home 中的 index、日志和镜像 cache 不再需要。
