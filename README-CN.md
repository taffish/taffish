# TAFFISH 二进制分发

[English](README.md) | [中文](README-CN.md)

TAFFISH 是 TAFFISH 生态系统的本地命令行部分：

- `taffish`：将 `.taf` 程序编译为 shell。
- `taf`：管理 TAFFISH app 项目和本地 TAFFISH Hub 包。

当前仓库只分发预编译二进制文件，包含安装脚本、shell 自动补全文件、Vim 语法高亮文件，以及各平台的二进制资产。

## 目录

- [TAFFISH 生态入口](#taffish-生态入口)
- [支持平台](#支持平台)
- [快速安装](#快速安装)
  - [标准安装](#标准安装)
  - [中国地区用户](#中国地区用户)
  - [验证安装](#验证安装)
- [系统需求](#系统需求)
  - [macOS 依赖](#macos-依赖)
  - [Linux 依赖](#linux-依赖)
- [安装路径](#安装路径)
- [运行时配置和镜像源](#运行时配置和镜像源)
- [安装器选项](#安装器选项)
- [本地或离线安装](#本地或离线安装)
- [容器后端](#容器后端)
  - [Docker](#docker)
  - [Podman](#podman)
  - [Apptainer](#apptainer)
- [GitHub 和发布依赖](#github-和发布依赖)
- [Shell 自动补全](#shell-自动补全)
- [Vim 语法高亮](#vim-语法高亮)
- [基础使用](#基础使用)
- [故障排查](#故障排查)
- [Release 接口](#release-接口)
- [项目状态](#项目状态)

## TAFFISH 生态入口

TAFFISH 当前由多个 GitHub 仓库和一个静态网页版 Hub 共同组成：

| 资源 | 作用 |
| --- | --- |
| [taffish/taffish](https://github.com/taffish/taffish) | 当前仓库。本地 `taf` 和 `taffish` 命令的二进制分发仓库。 |
| [TAFFISH Hub](https://taffish.github.io) | 网页版 app registry，用来浏览当前可用的 TAFFISH apps、tools、flows、版本、依赖和安装命令。 |
| [taffish/taffish-docs](https://github.com/taffish/taffish-docs) | 开发者文档，覆盖 TAFFISH 语言、app 项目、Hub 架构、容器、依赖、`taffish.toml` 和 index schema。 |
| [taffish/taffish-index](https://github.com/taffish/taffish-index) | 静态 package index，供 `taf update`、`taf search`、`taf info` 和 `taf install` 使用。 |
| [taffish/taffish.github.io](https://github.com/taffish/taffish.github.io) | 网页版 Hub 的源码仓库。 |
| [taffish/.github](https://github.com/taffish/.github) | GitHub 组织首页和项目总览。 |

当前 Hub 设计有意保持 GitHub-based：每个 TAFFISH app 都是一个独立仓库，
release tag 标识不可变 app 版本，app 仓库各自构建容器镜像，
`taffish-index` 发布静态 JSON 索引，本地 `taf` 命令消费这个索引。

## 支持平台

当前二进制资产：

| 平台 | 资产后缀 | 构建后端 | 说明 |
| --- | --- | --- | --- |
| macOS Apple Silicon | `darwin-arm64` | SBCL | 需要 Homebrew 的 `zstd` 运行时库。 |
| Linux x86_64 | `linux-amd64` | LispWorks | 运行依赖很少；需要基于 glibc 的 Linux。 |

当前未提供：

- macOS Intel (`darwin-amd64`)
- Linux ARM64 (`linux-arm64`)
- Windows
- Alpine/musl Linux 二进制资产

可以用 `--os` 和 `--arch` 强制选择平台，但对应二进制资产必须已经存在于所选版本的 `target/` 下。

## 快速安装

### 标准安装

如果你在中国大陆，或者遇到 GitHub raw 网络问题，请使用后面的
[中国地区用户安装方式](#中国地区用户)。

用户级安装，推荐普通用户使用。它只为当前用户安装 `taf` 和 `taffish`，不需要管理员权限：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

系统级安装适合共享服务器或公共工作站，需要管理员权限，会为设备上的所有用户安装命令：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sudo sh -s -- --system
```

固定版本安装。安装器本身可以来自 `main`，实际下载内容会固定到指定 git tag：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.2.1 --user
```

### 中国地区用户

中国大陆访问 GitHub raw 可能较慢或被阻断。Gitee 安装器会从 Gitee 镜像下载文件，并在没有配置文件时自动初始化中国镜像配置。

macOS 用户注意：Gitee 可能会要求登录后才能匿名下载较大的 `raw` 二进制文件。如果 Gitee 安装器报错
`large file require login for access`，这是 Gitee raw 文件访问限制，不是 TAFFISH
安装器错误。这种情况下请使用 GitHub 安装方式并配置可用网络/代理，或者登录 Gitee 后手动下载对应的
macOS 二进制文件。Gitee 安装器目前更适合 Linux amd64 服务器；Linux 二进制文件较小，通常不受这个限制影响。

用户级安装：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user
```

系统级安装适合共享服务器或公共工作站，需要管理员权限，会为设备上的所有用户安装命令：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sudo sh -s -- --system
```

固定版本安装：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --version 0.2.1 --user
```

如果需要强制把已有配置覆盖为 Gitee/中国镜像配置，添加 `--force-config`：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user --force-config
```

### 验证安装

安装后验证：

```sh
taf --version
taffish --version
taf doctor
```

如果安装器提示 `~/.local/bin` 不在 `PATH` 中，把下面这一行加入你的 shell 配置文件：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

然后打开一个新 shell，或者运行 `source ~/.zshrc` / `source ~/.bashrc`。

## 系统需求

安装器需要标准 POSIX 用户态工具：

```text
sh, uname, tar, mktemp, cp, chmod, mkdir, find, dirname
```

在线安装还需要一个下载工具：

```text
curl or wget
```

`taf update` 默认从 GitHub 下载 TAFFISH index。在 GitHub raw 内容被阻断或网络不稳定的环境中，安装本身仍然可以完成，但 `taf update` 可能会输出 warning。可以之后重试：

```sh
taf update
```

或者使用镜像/自定义 index：

```sh
taf update --url <INDEX-URL>
```

### macOS 依赖

当前 macOS 二进制由 SBCL 构建，并动态链接 Homebrew 的 `zstd` 库：

```text
/opt/homebrew/opt/zstd/lib/libzstd.1.dylib
```

Apple Silicon macOS 上可以这样安装：

```sh
brew install zstd
```

当前 macOS 资产是 `darwin-arm64`，面向 Apple Silicon。当前二进制 release 不覆盖 Intel macOS。

项目开发和发布可能需要的可选工具：

```sh
brew install git gh podman zstd squashfs
```

只需要安装你实际打算使用的容器后端。

### Linux 依赖

当前 Linux 二进制由 LispWorks 构建，运行依赖很轻。它是动态链接的 x86_64 ELF，适用于基于 glibc 的 Linux 系统。

实际基线：

- x86_64 Linux
- 基于 glibc 的发行版，不是 Alpine/musl
- 当前 ELF 显示的 GNU/Linux kernel 基线：`2.6.32`
- 简单文档规则：glibc >= 2.6
- 当前二进制的 GLIBC symbol 需求较低

Debian/Ubuntu 上，基础系统通常足够运行 `taf` 和 `taffish`：

```sh
sudo apt-get update
sudo apt-get install -y curl tar git
```

如果需要发布项目到 GitHub：

```sh
sudo apt-get install -y git gh
```

如果需要运行容器，需要至少安装一个容器后端。见下方容器部分。

## 安装路径

用户级安装默认路径：

```text
bin  = ~/.local/bin
home = ~/.local/share/taffish
```

系统级安装默认路径：

```text
bin  = /usr/local/bin
home = /opt/taffish
```

TAFFISH home 用于保存本地 apps、indexes、缓存镜像、命令启动器、补全文件、Vim 文件、日志和其他运行时数据。

相关环境变量：

```text
TAFFISH_USER_HOME        覆盖用户级 TAFFISH home
TAFFISH_SYSTEM_HOME      覆盖系统级 TAFFISH home
TAFFISH_SYSTEM_BIN_DIR   覆盖系统级命令 bin 目录
TAFFISH_CONFIG           使用一个显式 config.toml 文件
TAFFISH_INDEX_URL        覆盖 taf update 的默认 index URL
```

自定义用户级安装示例：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh \
  | sh -s -- --user --bin-dir "$HOME/bin" --taffish-home "$HOME/.taffish"
```

自定义 prefix 安装示例：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh \
  | sh -s -- --prefix "$HOME/opt/taffish"
```

## 运行时配置和镜像源

TAFFISH `0.2.1` 添加了一个很小的运行时配置文件，用来稳定支持镜像源和自定义源。默认配置路径是：

```text
用户级 = ~/.local/share/taffish/config.toml
系统级 = /opt/taffish/config.toml
```

查看当前生效配置：

```sh
taf config
taf config path
```

初始化默认 GitHub profile：

```sh
taf config init --github
```

初始化中国镜像 profile 模板：

```sh
taf config init --china --force
taf update
```

生成的中国镜像模板有意保持简单：

```toml
schema_version = "taffish.config/v1"
profile = "china"
language = "en"

[index]
url = "https://gitee.com/taffish-org/taffish-index/raw/main/index/index.json"

[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

含义：

- `[index].url` 控制 `taf update` 从哪里下载静态 index。
- `[[source.rewrite]]` 会在 `taf install` clone app 仓库时重写 index 里的 canonical source URL。
- `taf publish` 仍然只支持 GitHub；镜像源是读取和安装路径，不是发布目标。
- `taf update --url <INDEX-URL>` 和 `TAFFISH_INDEX_URL` 仍可作为一次性覆盖。

如果你的镜像组织名或内网 Git 服务路径不同，直接编辑 `config.toml` 即可。镜像侧需要提供兼容的仓库、tag 和相同的 TAFFISH index schema。

## 安装器选项

```text
--user                    为当前用户安装 [默认]
--system                  系统级安装
--prefix DIR              设置软件 prefix；默认推导 bin=DIR/bin，
                          home=DIR/share/taffish，除非被覆盖
--bin-dir DIR             覆盖可执行文件安装目录
--taffish-home DIR        覆盖 TAFFISH 运行时 home
--repo OWNER/REPO         GitHub 仓库 [taffish/taffish]
--version VERSION         Release 版本 [0.2.1]
--provider PROVIDER       Raw 提供方：github 或 gitee [github]
--raw-base-url URL        覆盖 raw base URL，应指向固定 tag
--os OS                   覆盖目标 OS (darwin|macos|linux)
--arch ARCH               覆盖目标架构 (amd64|x86_64|arm64|aarch64)
--taf-url URL             覆盖 taf 二进制 URL
--taffish-url URL         覆盖 taffish 二进制 URL
--share-url URL           用 tar.gz archive 覆盖 completion/vim 来源
--url URL                 从显式 URL 下载完整 bundle tarball
--archive FILE            从本地 tar.gz archive 安装
--config-profile PROFILE  初始化配置 profile：github、china 或 none
--force-config            config init 时覆盖已有配置
--no-update               安装后不运行 taf update
--no-doctor               安装后不运行 taf doctor --init
-h, --help                显示安装器帮助
```

手动覆盖平台检测示例：

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh \
  | sh -s -- --user --os linux --arch amd64
```

## 本地或离线安装

从已下载的 release bundle 安装：

```sh
sh install/install-taffish.sh --archive ./taffish-0.2.1-target.tar.gz --user
```

从显式 bundle URL 安装：

```sh
sh install/install-taffish.sh --url https://example.org/taffish.tar.gz --user
```

Bundle 结构：

```text
target/
  taf-<os>-<arch>-<version>
  taffish-<os>-<arch>-<version>
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
```

## 容器后端

TAFFISH app 脚本可以通过 Docker、Podman 或 Apptainer 运行工具命令。`.taf` tag 会选择或限制后端，例如：

```taf
<docker:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

```taf
<apptainer:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

```taf
<container:ghcr.io/taffish/my-tool:0.1.0-r1>
  my-tool --help
```

`<container:...>` 使用 TAFFISH 的后端顺序。默认偏好顺序：

```text
apptainer -> podman -> docker
```

你只需要安装实际打算使用的后端。本地开发时，`taf run --backend docker` / `taf run --backend podman` 可以强制后端，而不需要修改 `.taf` 脚本。

### Docker

Docker 适合开发者笔记本和许多工作站。

macOS：

```sh
brew install --cask docker
```

Debian/Ubuntu，使用发行版仓库的简化安装方式：

```sh
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker "$USER"
```

修改 `docker` 用户组后，需要登出并重新登录。

测试：

```sh
docker run --rm hello-world
```

### Podman

Podman 适合偏好 daemonless container 的场景。

macOS：

```sh
brew install podman
podman machine init
podman machine start
```

Debian/Ubuntu：

```sh
sudo apt-get update
sudo apt-get install -y podman
```

测试：

```sh
podman run --rm hello-world
```

### Apptainer

Apptainer 是许多 HPC 和共享 Linux 服务器上的推荐后端。它避免了普通用户需要 Docker daemon 权限的问题。

Debian/Ubuntu 上不同发行版的软件包情况可能不同。如果可用：

```sh
sudo apt-get update
sudo apt-get install -y apptainer squashfs-tools squashfuse fuse2fs gocryptfs
```

对于 Docker/OCI 镜像，实际最低依赖：

```text
apptainer      运行 Apptainer 后端所需
mksquashfs     由 squashfs-tools 提供；用于把 Docker/OCI image 转成 SIF
squashfuse     推荐安装；允许直接挂载 SIF，避免每次转成临时 sandbox
fuse2fs        可选；消除 Apptainer EXT3 filesystem warning
gocryptfs      可选；消除 Apptainer encrypted filesystem warning
```

如果缺少 `mksquashfs`，首次镜像转换可能失败，并出现：

```text
while searching for mksquashfs: executable file not found in $PATH
```

安装：

```sh
sudo apt-get install -y squashfs-tools
```

如果缺少 `squashfuse`，后续运行可能可以成功，但 Apptainer 会输出：

```text
INFO: squashfuse not found, will not be able to mount SIF or other squashfs files
INFO: Converting SIF file to temporary sandbox...
INFO: Cleaning up image...
```

安装：

```sh
sudo apt-get install -y squashfuse
```

`v0.1.2` 及之后构建的 TAFFISH 生成脚本默认使用 `apptainer --quiet`，让正常 app 输出更干净。运行时错误仍然会报告。

## GitHub 和发布依赖

普通安装和普通 app 运行不需要 GitHub 登录。

这些命令可能需要 Git/GitHub 工具：

```text
taf publish
taf new --docker   (创建 GitHub Actions workflow 文件)
taf update         (下载 index，除非使用本地 URL)
taf install        (克隆本地 index 引用的 app 仓库)
```

推荐开发者设置：

```sh
git --version
gh auth login
```

TAFFISH 不会在内部处理 GitHub 登录。请在 TAFFISH 外部配置 SSH keys、Git credential helper 或 GitHub CLI 认证。

## Shell 自动补全

安装器会把补全文件复制到：

```text
$TAFFISH_HOME/share/completions
```

用户级安装通常是：

```text
~/.local/share/taffish/share/completions
```

Bash：

```sh
source ~/.local/share/taffish/share/completions/bash/taf
source ~/.local/share/taffish/share/completions/bash/taffish
```

Zsh：

```sh
fpath=(~/.local/share/taffish/share/completions/zsh $fpath)
autoload -Uz compinit
compinit
```

Fish：

```sh
mkdir -p ~/.config/fish/completions
cp ~/.local/share/taffish/share/completions/fish/taf.fish ~/.config/fish/completions/
cp ~/.local/share/taffish/share/completions/fish/taffish.fish ~/.config/fish/completions/
```

## Vim 语法高亮

安装器会把 Vim 文件复制到：

```text
$TAFFISH_HOME/share/vim
```

用户级安装：

```sh
mkdir -p ~/.vim/syntax ~/.vim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.vim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.vim/ftdetect/
```

Neovim：

```sh
mkdir -p ~/.config/nvim/syntax ~/.config/nvim/ftdetect
cp ~/.local/share/taffish/share/vim/syntax/taf.vim ~/.config/nvim/syntax/
cp ~/.local/share/taffish/share/vim/ftdetect/taf.vim ~/.config/nvim/ftdetect/
```

## 基础使用

更新本地 index：

```sh
taf update
```

搜索 apps：

```sh
taf search blast
```

查看 app 信息：

```sh
taf info taf-my-tool
```

安装 app 或 command：

```sh
taf install taf-my-tool
```

运行带版本的 command：

```sh
taf-my-tool-v0.1.0-r1 --help
```

创建并运行本地项目：

```sh
taf new my-flow
cd my-flow
taf check
taf run
```

构建带版本的 command wrapper：

```sh
taf build
./target/taf-my-flow-v0.1.0-r1
```

## 故障排查

### `taf: command not found`

安装 bin 目录不在 `PATH` 中。

用户级安装：

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### `taf update` 出现 GitHub connection reset

这通常是访问 GitHub raw 内容时的网络/代理问题。可以之后重试，设置代理，或者使用自定义 index URL：

```sh
taf update --url <INDEX-URL>
```

如果需要持久使用镜像源配置：

```sh
taf config init --china --force
taf update
```

### macOS 提示缺少 `libzstd.1.dylib`

安装 Homebrew `zstd`：

```sh
brew install zstd
```

### Apptainer 提示缺少 `mksquashfs`

安装 `squashfs-tools`：

```sh
sudo apt-get install -y squashfs-tools
```

### Apptainer 每次运行都输出 `Converting SIF file to temporary sandbox...`

安装 `squashfuse`：

```sh
sudo apt-get install -y squashfuse
```

### Docker permission denied

把自己加入 `docker` 用户组，并开启一个新的登录会话：

```sh
sudo usermod -aG docker "$USER"
```

## Release 接口

Raw 安装器通常从 `main` 下载，但实际安装内容由 `--version` 固定到一个 git tag：

```text
https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taf-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taffish-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/completion/...
https://raw.githubusercontent.com/taffish/taffish/v<version>/vim-highlight/...
```

Gitee 安装器使用同样的版本化布局：

```text
https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh
https://gitee.com/taffish-org/taffish/raw/v<version>/target/...
```

## 项目状态

本仓库是第一个公开 TAFFISH 本地 CLI release 系列的二进制分发通道。源码暂未在此公开。
