# TAFFISH

[English](README.md) | [中文](README-CN.md)

TAFFISH 是一个面向生物信息学命令级可复现执行的 shell-native 可执行包框架。

它将生物信息学命令行工具调用转化为可版本化、可容器解析、可安装、可组合的
shell 命令，使这些命令既可以在普通 shell 中直接使用，也可以嵌入现有工作流系统。

当前仓库提供 TAFFISH 核心工具的本地命令行实现、安装器、源码树文档、shell 自动补全文件、
Vim 语法高亮文件，以及面向支持平台的手动构建二进制 release 载荷。

本地命令行工具包括：

- `taffish`：将 `.taf` 程序编译为 shell。
- `taf`：管理 TAFFISH app 项目和本地 TAFFISH Hub 包。
- `taffish-mcp`：通过 stdio MCP 为 AI 客户端暴露安全的 TAFFISH tools/resources/prompts。

当前 release 载荷包含 SHA256 checksum manifest、GPG 签名的 checksum
manifest 和公开 release key。对于 taf-app，Hub 可信模型基于 index 中记录的
源码 commit、容器 digest / platform 元数据和 smoke metadata。

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
- [从源码构建](#从源码构建)
- [容器后端](#容器后端)
  - [Docker](#docker)
  - [Podman](#podman)
  - [Apptainer](#apptainer)
- [TAF App Smoke 元数据](#taf-app-smoke-元数据)
- [GitHub 和发布依赖](#github-和发布依赖)
- [Shell 自动补全](#shell-自动补全)
- [Vim 语法高亮](#vim-语法高亮)
- [基础使用](#基础使用)
- [MCP / AI 集成](#mcp--ai-集成)
- [故障排查](#故障排查)
- [Release 接口](#release-接口)
- [Release 校验](#release-校验)
- [项目状态](#项目状态)
- [许可证](#许可证)

## TAFFISH 生态入口

TAFFISH 当前由多个 GitHub 仓库和一个静态网页版 Hub 共同组成：

| 资源 | 作用 |
| --- | --- |
| [taffish/taffish](https://github.com/taffish/taffish) | 当前仓库。包含 `taf`、`taffish` 和 `taffish-mcp` 的源码、安装器、`docs/` 下的源码树文档、补全文件、Vim 文件和二进制 release 载荷。 |
| [TAFFISH Hub](https://taffish.github.io) | 网页版 app registry，用来浏览当前可用的 TAFFISH apps、tools、flows、版本、依赖和安装命令。 |
| [taffish/taffish-docs](https://github.com/taffish/taffish-docs) | 面向用户和 app 作者的公开文档仓库，用于放置快速开始、教程、app 开发指南和整理后的生态文档。 |
| [taffish/taffish-index](https://github.com/taffish/taffish-index) | 静态 package index，供 `taf update`、`taf search`、`taf info`、`taf install`、`taf outdated` 和 `taf upgrade` 使用。 |
| [taffish/taffish.github.io](https://github.com/taffish/taffish.github.io) | 网页版 Hub 的源码仓库。 |
| [taffish/.github](https://github.com/taffish/.github) | GitHub 组织首页和项目总览。 |
| [Gitee 上的 taffish-org](https://gitee.com/taffish-org) | 中国地区镜像组织，用于 GitHub raw 网络不稳定时的安装和 index 访问。 |

当前 Hub 设计有意保持 GitHub-based：每个 TAFFISH app 都是一个独立仓库，
release tag 标识不可变 app 版本，app 仓库各自构建容器镜像，
`taffish-index` 发布静态 JSON 索引，本地 `taf` 命令消费这个索引。

文档也刻意分层。本仓库的 `docs/` 目录贴近源码，用来保存实现说明、规范草案、
架构判断和 release engineering 细节。独立的 `taffish/taffish-docs` 仓库则面向
更广泛的公开读者，适合放快速开始、教程、app 作者指南和用户侧生态文档。

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

这个列表只表示当前没有官方预构建二进制资产。只要目标平台有可用的 SBCL 环境和
所需 POSIX 工具，TAFFISH 仍然可以从源码本地构建；见[从源码构建](#从源码构建)。

可以用 `--os` 和 `--arch` 强制选择平台，但对应二进制资产必须已经存在于所选版本的 `target/` 下。

## 快速安装

### 标准安装

如果你在中国大陆，或者遇到 GitHub raw 网络问题，请使用后面的
[中国地区用户安装方式](#中国地区用户)。

用户级安装，推荐普通用户使用。它只为当前用户安装 `taf`、`taffish` 和 `taffish-mcp`，不需要管理员权限：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

系统级安装适合共享服务器或公共工作站，需要管理员权限，会为设备上的所有用户安装命令：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sudo sh -s -- --system
```

固定版本安装。安装器本身可以来自 `main`，实际下载内容会固定到指定 git tag：

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --version 0.10.0 --user
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
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --version 0.10.0 --user
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
taffish-mcp --version
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

Debian/Ubuntu 上，基础系统通常足够运行 `taf`、`taffish` 和 `taffish-mcp`：

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

当前 TAFFISH 是 `0.10.0`。运行时配置文件从 `0.2.0` 开始引入，用来稳定支持镜像源和自定义源。默认配置路径是：

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
--version VERSION         Release 版本 [0.10.0]
--provider PROVIDER       Raw 提供方：github 或 gitee [github]
--raw-base-url URL        覆盖 raw base URL，应指向固定 tag
--os OS                   覆盖目标 OS (darwin|macos|linux)
--arch ARCH               覆盖目标架构 (amd64|x86_64|arm64|aarch64)
--taf-url URL             覆盖 taf 二进制 URL
--taffish-url URL         覆盖 taffish 二进制 URL
--taffish-mcp-url URL     覆盖 taffish-mcp 二进制 URL
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
sh install/install-taffish.sh --archive ./taffish-0.10.0-target.tar.gz --user
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
  taffish-mcp-<os>-<arch>-<version>
completion/
  bash/
  zsh/
  fish/
vim-highlight/
  syntax/
  ftdetect/
```

## 从源码构建

大多数用户应优先使用上面的预构建二进制安装方式。维护者和贡献者如果需要测试实现、
修改 TAFFISH，或生成本地二进制，可以从源码构建。

详见专门的源码构建文档：

- [从源码构建](docs/dev/zh-CN/build-from-source.md)

当前官方二进制载荷由维护者手动构建：macOS Apple Silicon 二进制由 SBCL 构建，
Linux x86_64 二进制由 LispWorks 构建。`target/` 下保留了
`SHA256SUMS`、`SHA256SUMS.asc` 和发布公钥，供用户进行手动校验。

源码构建会生成不带后缀的本地二进制：

```text
target/taf
target/taffish
target/taffish-mcp
```

版本化的 `target/*-<os>-<arch>-<version>` 文件是维护者 release 载荷，用于 raw 安装器。

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

对于已经安装好的 `taf-*` 命令，或者直接使用 `taffish` 编译时，可以设置
`TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`，在运行时强制通用
`<container:...>` tag 使用指定后端：

```sh
TAFFISH_CONTAINER_BACKEND=podman taf-my-tool-v0.1.0-r1 [ARGS...]
TAFFISH_CONTAINER_BACKEND=podman taf-my-tool-v0.1.0-r1 --compile -- [ARGS...]
```

这个环境变量不会覆盖显式的 `<docker:...>`、`<podman:...>` 或
`<apptainer:...>` tag。`taf run --backend ...` 的优先级高于这个环境变量。

TAFFISH 支持两种 backend-specific runtime args。对于 app 本身需要的运行参数，
建议写进 `.taf` tag：

```taf
<container:ghcr.io/taffish/my-gpu-tool:1.0.0-r1$@[docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
  my-gpu-tool --help
```

结构化 runtime args 使用 `$@[target: args]` block。支持的 target 包括
`all`、`container`（`all` 的别名）、`docker`、`podman`、`apptainer`，
以及 `docker/podman` 这样的后端组合：

```taf
<container:ghcr.io/taffish/my-tool:1.0.0-r1$@[all: --network host][docker/podman: --security-opt=label=disable]>
  my-tool --help
```

对于本机运行时策略，使用环境变量，不需要修改 `.taf` 脚本：

```sh
TAFFISH_DOCKER_RUN_ARGS="--gpus all" taf-my-tool-v0.1.0-r1
TAFFISH_PODMAN_RUN_ARGS="--device nvidia.com/gpu=all" taf-my-tool-v0.1.0-r1
TAFFISH_APPTAINER_RUN_ARGS="--nv" taf-my-tool-v0.1.0-r1
```

最终 runtime args 顺序是：TAFFISH 默认参数、project/context 配置参数、tag 参数、
本地环境变量参数。这样 app 作者可以声明 app 自身要求，本地用户仍然可以在末尾追加
站点或机器相关策略。

旧的 all-backend 参数语法仍然支持：

```taf
<container:ghcr.io/taffish/my-tool:0.1.0-r1$--network host>
```

### Docker

Docker 适合开发者笔记本和许多工作站。
官方安装文档：[Install Docker](https://docs.docker.com/en/latest/installation/)
和 [Install Docker Desktop on Mac](https://docs.docker.com/desktop/setup/install/mac-install/)。

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
官方安装文档：[Podman Installation](https://podman.io/docs/installation)。

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
官方安装文档：[Installing Apptainer](https://apptainer.org/docs/admin/main/installation.html)。

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

## TAF App Smoke 元数据

TAFFISH `0.8.0` 增加了面向容器化 taf-app 的声明式 smoke 元数据。
这是 TAFFISH Hub 供应链/可信模型在本地项目侧的第一块基础：项目可以声明
index 自动化在接纳一个容器镜像进入公开 index 前，至少应该验证哪些命令。

`taf new --tool --docker` 现在会在 `taffish.toml` 中创建 `[smoke]`：

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["TODO"]
test = ["TODO --help"]
```

含义：

- `backend`：推荐 smoke 后端，可选 `docker`、`podman` 或 `apptainer`。
- `timeout`：每条 smoke command 的超时时间，单位为秒。
- `exist`：应该能在容器 `PATH` 中找到的可执行命令名。
- `test`：应该以退出码 `0` 正常结束的 shell 命令。

`taf check` 只验证结构，并要求声明了 `[container].image` 或
`[container].dockerfile` 的项目必须提供 `[smoke]`。它也会拒绝默认 `TODO`
占位，因此需要先把它们替换成真实 app-specific checks，再运行 `taf check`、
`taf publish` 或进入 index。`taf check` 不会在本地运行 smoke test。真正的
smoke 执行属于 TAFFISH Hub/index 自动化，因为那里可以稳定地检查最终推送的镜像、
digest 和平台元数据。本地/私有安装会保留 smoke 元数据，方便企业或离线 index
以后执行同样的策略。

## GitHub 和发布依赖

普通安装和普通 app 运行不需要 GitHub 登录。

这些命令可能需要 Git/GitHub 工具：

```text
taf publish
taf new --docker   (创建 GitHub Actions workflow 文件)
taf update         (下载 index，除非使用本地 URL)
taf install        (克隆本地 index 引用的 app 仓库)
taf install --from (复制并安装私有/本地 TAFFISH 项目)
```

推荐开发者设置：

```sh
git --version
gh auth login
```

TAFFISH 不会在内部处理 GitHub 登录。请在 TAFFISH 外部配置 SSH keys、Git credential helper 或 GitHub CLI 认证。

如果本地 index 提供了 `source.commit`，`taf install` 会在构建 command wrapper 前
校验安装源码确实解析到该 Git commit，并且源码工作区是干净的。这样 source
rewrite / mirror 安装可以保持可审计，同时不需要改写 app 源码文件。

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

计划或批量安装 index 中的 app：

```sh
taf install --all
taf install --all --kind tool --yes
taf install --all --flows --yes
```

`taf install --all` 默认是 dry-run。需要真实安装时添加 `--yes`。
可以用 `--kind tool|flow|all`、`--tools` 或 `--flows` 限制批量范围。
添加 `--prune-old` 可以在批量安装成功后移除本地旧版本。`taf uninstall`、
`taf upgrade --prune-old` 和 `taf prune` 只会删除 TAFFISH app 源码和
wrapper 文件，不会删除共享的 Docker、Podman、Apptainer 或 SIF 镜像缓存。

检查并应用本地 app 更新：

```sh
taf outdated
taf outdated --json
taf upgrade
taf upgrade --yes
taf upgrade taf-my-tool --yes --prune-old
```

`taf outdated` 和 `taf upgrade` 会把本地 install metadata 与当前本地 index
进行比较，所以建议先运行 `taf update`。通过 `taf install --from` 安装的
本地/私有 app 会被视为私有来源，并被公开 index 的 upgrade 跳过。

移除旧版本，只保留每个 app 的本地最新版本：

```sh
taf prune
taf prune --yes
taf prune --kind flow --yes
```

安装没有发布到公开 Hub 的私有/本地 app 项目：

```sh
taf install --from /path/to/my-private-tool
taf list
taf which taf-my-private-tool
```

`taf install --from` 会读取本地项目的 `taffish.toml`、检查项目、把当前工作树复制到选定的
TAFFISH home、构建带版本的 command wrapper，并把安装来源记录为
`[local-project] <PROJECT-ROOT>`。`PROJECT-DIR` 可以是项目根目录，也可以是项目内任意子目录；
TAFFISH 会向上搜索 `taffish.toml`。它不需要先运行 `taf update`，也不会自动安装依赖。

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

带发布说明发布：

```sh
taf publish --release --dry-run
taf publish --release --yes
```

`taf new` 会创建一个被 ignore 的 `release.md` 草稿。使用 `taf publish --release`
时，`release.md` 第一行会成为 publish message，整个文件会成为 GitHub Release notes。
发布前需要替换默认的 `# TODO: release summary` 第一行。

## MCP / AI 集成

TAFFISH `0.4.0` 引入了 `taffish-mcp`，这是一个保守的 stdio MCP server，
面向 AI 客户端暴露 TAFFISH 能力。TAFFISH `0.5.0` 增加了只读的 TAF
源码/文件编译器工具，TAFFISH `0.6.0` 继续增加了面向 AI 的 taf-app inspection、
当前项目 inspection 和安全的 app invocation compile。TAFFISH `0.7.0` 让 MCP
compile 工具与运行时容器 backend override 保持一致。TAFFISH `0.8.0`
会在容器化 taf-app inspection 中暴露 smoke/trust 元数据，但不会运行 smoke
test 或启动容器。TAFFISH `0.10.0` 增加了用于
outdated/install-all/upgrade/prune 工作流的安全 package 维护计划工具：

- `taffish_get_version` / `taffish_get_help`
- `taffish_validate_source` / `taffish_validate_file`
- `taffish_compile_source` / `taffish_compile_file`
- `taffish_summarize_source` / `taffish_summarize_file`
- `taffish_resolve_app`
- `taffish_inspect_app`
- `taffish_summarize_app_usage`
- `taffish_compile_app_invocation`
- `taffish_check_outdated`
- `taffish_plan_install_all`
- `taffish_plan_upgrade`
- `taffish_plan_prune`
- `taffish_check_project`
- `taffish_inspect_project`
- `taffish_summarize_project_usage`
- `taffish_compile_project`

MCP 接口还提供相对安全的 project、Hub、config、history、resource 和 prompt
操作，不暴露 `taf run`、`taf publish` 或镜像构建动作。app invocation compile
以及 source/project compile 只校验参数并返回生成的 shell code，不会运行 app 或项目。

对于 MCP compile 工具，如果 backend 选择很重要，优先显式传入 `containerBackend`。
如果没有传入这个参数，则会在设置时使用
`TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`；显式 `containerBackend`
始终具有更高优先级。

MCP 客户端配置示例：

```json
{
  "mcpServers": {
    "taffish": {
      "command": "taffish-mcp",
      "args": []
    }
  }
}
```

这样 AI 客户端可以先通过结构化接口检查当前 TAFFISH 项目和已安装 taf-app、验证或编译
`.taf` 源码但不执行、搜索本地 index、读取 `taffish.toml`、`src/main.taf`、
`docs/help.md`、`release.md` 等项目资源，并准备安全的项目操作，而不是一开始就依赖非结构化终端文本。

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
https://raw.githubusercontent.com/taffish/taffish/v<version>/target/taffish-mcp-<os>-<arch>-<version>
https://raw.githubusercontent.com/taffish/taffish/v<version>/completion/...
https://raw.githubusercontent.com/taffish/taffish/v<version>/vim-highlight/...
```

Gitee 安装器使用同样的版本化布局：

```text
https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh
https://gitee.com/taffish-org/taffish/raw/v<version>/target/...
```

## Release 校验

当前二进制 release 载荷保留在 `target/` 下，这样 GitHub 和 Gitee raw 安装器可以使用同一套固定 tag 的文件布局。0.10.0 release 包含这些校验文件：

```text
target/SHA256SUMS
target/SHA256SUMS.asc
target/TAFFISH-RELEASE-KEY.asc
```

可直接复制到 GitHub release 页面的 release note 草稿保存在
[docs/releases/v0.10.0.zh-CN.md](docs/releases/v0.10.0.zh-CN.md)，英文版见
[docs/releases/v0.10.0.md](docs/releases/v0.10.0.md)。

Raw 安装器主要负责下载并安装固定版本文件；它当前不会自动校验 `SHA256SUMS`
或 GPG 签名。如果需要高安全安装，应先下载对应 tag 内容或 release bundle，
手动校验 checksum manifest 和签名后，再从已经验证过的本地文件安装。

校验 SHA256：

```sh
cd target
shasum -a 256 -c SHA256SUMS
```

校验 checksum 签名：

```sh
gpg --import TAFFISH-RELEASE-KEY.asc
gpg --verify SHA256SUMS.asc SHA256SUMS
```

信任 `TAFFISH-RELEASE-KEY.asc` 之前，请把导入后的 release key fingerprint 和下面这个公开 fingerprint 对比：

```text
F863 33E6 0BD6 74F1 59A5  651A B919 3F30 C424 7BB2
```

当前 `0.10.0` checksum manifest：

```text
ac403e7913bbe291c8a900952db237cfbabdf3e57ee6616bc55911d1fb99979b  taf-darwin-arm64-0.10.0
1e5b6ffb967768c49f4d88fb960d991998c81c3d4c8e50a2e541ff134d6484f8  taf-linux-amd64-0.10.0
82c84886247a19c8d49ad27245ed85a08429bf309a0268439782f83eb3a4f7d6  taffish-darwin-arm64-0.10.0
8bc8456d10280d381bab73ddbe001aca1be6ead72b0f551e6b5a731ec043fe16  taffish-linux-amd64-0.10.0
2f5875dfbef59e7ba4aa533fa334e0464317eba7473e35cbb6726dbc35488e28  taffish-mcp-darwin-arm64-0.10.0
cdea1678a198ff372f3717bf0b99bdf7f6ac3e1325e417065f5b1e52456b779d  taffish-mcp-linux-amd64-0.10.0
```

这可以确认 checksum manifest 由 TAFFISH release key 签名。它目前还不表示已经具备 GitHub Actions provenance、artifact attestation 或可复现构建。这些属于后续 release infrastructure 的供应链安全改进。

## 项目状态

本仓库是 TAFFISH 本地 CLI release 系列的开源源码仓库。当前仍然在 `target/` 下保留手动构建的二进制载荷，以支持 GitHub/Gitee raw 安装器按固定 tag 安装。

## 许可证

TAFFISH 使用 [Apache License 2.0](LICENSE) 开源。安全报告和贡献说明见
[SECURITY.md](SECURITY.md) 与 [CONTRIBUTING.md](CONTRIBUTING.md)。
