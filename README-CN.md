# TAFFISH

[English](README.md) · [简体中文](README-CN.md) · [官网](https://taffish.com/) · [浏览 Hub](https://taffish.github.io/)

**将可复现性带回 shell。** TAFFISH 把生物信息学工具和轻量流程封装成带版本的命令，可以直接用在已有的 shell 脚本、HPC 作业或工作流中。

例如，安装 FastQC app 后，下面这行命令就能对当前目录中的 FASTQ 文件做质量检查。

```sh
taf-fastqc-v0.12.1-r1 fastqc reads.fq.gz
```

把脚本交给别人，对方就能从这行命令读出 FastQC 的版本（`0.12.1`）和 TAFFISH 的封装修订号（`r1`）。在命令名后加上 `--compile`，还能查看生成的 shell，看到它选用哪个容器镜像、把哪些参数传给 FastQC。至于这一步放在分析的什么位置、怎样与其他工具组合，仍由你的脚本决定。[为什么 TAFFISH 选择命令这一层](https://taffish.com/stories/positioning/)

<a name="目录"></a>

[工作原理](#taffish-如何工作) · [快速安装](#快速安装) · [离线安装](#本地或离线安装) · [试用 FastQC](#首次使用) · [更新与升级](#更新与升级) · [更多指南](#按需查阅)

<a name="taffish-生态入口"></a>

## TAFFISH 如何工作

1. **描述工具或流程。** app 作者用 `.taf` 文件描述命令、参数和需要的容器镜像，`taffish` 编译器将它翻译为 POSIX shell。项目的 `taffish.toml` 记录版本、封装修订号和依赖关系。一个 flow 可以在同一份脚本中调用多个固定版本的 app。
2. **找到并安装指定版本。** 你可以浏览 Hub，也可以用 `taf` 搜索索引。`taf install` 安装所选 app 的源码和 shell 启动脚本。带版本的命令对应一个确定的发行版。像 `taf-fastqc` 这样的简短别名则指向同一安装范围内已装的最新版本。[在 Hub 查看示例所用的 FastQC 0.12.1-r1](https://taffish.github.io/?lang=zh&pkg=fastqc&ver=0.12.1-r1)
3. **在 shell 中运行。** 对于容器化 app，启动脚本会调用 Docker、Podman 或 Apptainer。首次运行时，后端会按需获取缺少的镜像，之后复用缓存。同一条命令也可以放进更大的脚本或工作流。

需要接入 AI 客户端时，`taffish-mcp` 通过标准输入输出上的 MCP 接口提供 app 检查、参数处理和编译能力。日常命令行使用可以直接从 `taf` 开始。[系统架构](docs/architecture/README.zh-CN.md) · [MCP 接口](docs/standards/zh-CN/mcp-interface-spec.md)

## 快速安装

按网络条件选择 [GitHub](#github)、[Gitee](#gitee) 或[本地离线安装](#本地或离线安装)。0.12.0 的官方平台包包含 `taf`、`taffish` 和 `taffish-mcp`，构建时已包含 Han Lisp 0.3.0。安装和验证这三个命令无需另装 Lisp 或容器后端。[0.12.0 发布说明（英文）](docs/releases/v0.12.0.md)

| <a name="支持平台"></a><a name="系统需求"></a>平台 | 安装包 | 运行与解包依赖 |
| --- | --- | --- |
| <a name="macos-依赖"></a>Apple Silicon Mac，macOS 15 及以上 | `taffish-0.12.0-darwin-arm64.tar.xz` | 由不依赖 zstd 的 SBCL 2.4.9 构建，三个命令只链接 macOS 系统库。系统自带的 tar 即可解包，无需安装 Homebrew 或单独的 `xz`。 |
| <a name="linux-依赖"></a>使用 glibc 的 Linux x86-64 | `taffish-0.12.0-linux-amd64.tar.gz` | 由 LispWorks 构建，安装时需要 `tar` 和 `gzip`。 |

<a name="macos-提示缺少-libzstd1dylib"></a><a name="项目状态"></a>

**在 macOS 上从 TAFFISH 0.11.0 升级时，请将 Homebrew 的 `zstd` 保留到升级完成。** 安装器会先运行旧版 SBCL 命令，确认其身份后再替换。

<a name="标准安装"></a>

Linux 安装会显示 LispWorks 运行时条款并请求确认。无人值守安装请先阅读，再添加 `--accept-runtime-license`。[阅读与接受运行时条款](install/README-CN.md#运行时许可)

### GitHub

使用默认在线入口，为当前用户安装。

```sh
curl -fsSL https://raw.githubusercontent.com/taffish/taffish/main/install/install-taffish.sh | sh -s -- --user
```

<a name="中国地区用户"></a>

### Gitee

中国地区可使用 Gitee 下载同一平台包。首次安装时，该入口会为新配置选用国内索引。

macOS 安装时会自动下载并合并压缩包分片；GitHub 和 Linux 下载仍使用完整压缩包。

```sh
curl -fsSL https://gitee.com/taffish-org/taffish/raw/main/install/install-taffish.gitee.sh | sh -s -- --user
```

<a name="选择用户级或系统级-scope"></a><a name="安装路径"></a><a name="安装器选项"></a>

需要为所有用户安装时，将上面任选一条命令末尾的 `sh -s -- --user` 换成 `sudo sh -s -- --system`。要固定安装器和平台包的版本，从同一发行标签下载安装脚本。[固定版本安装](install/README-CN.md#安装入口) · [共享服务器与安装路径](install/README-CN.md#默认路径和-scope)

### 本地或离线安装

如果已有带签名平台包的 0.12.0 仓库副本，在仓库根目录运行以下命令。

```sh
sh install/install-taffish.sh --local
```

<a name="release-接口"></a>

只给离线机器拷贝安装材料时，从同一版本取 **五个文件**，放进同一个目录。需要[安装脚本](install/install-taffish.sh)、本机平台的完整压缩包、`ARCHIVE-SHA256SUMS`、`ARCHIVE-SHA256SUMS.asc` 和 `TAFFISH-RELEASE-KEY.asc`。压缩包和后三个文件都在[平台包目录](target/packages-0.12.0/)中。如果拿到的只有 macOS 下载分片，请先[合并成完整压缩包](install/README-CN.md#0120-起的本地安装)。进入复制好的目录后运行以下命令。

```sh
sh install-taffish.sh --local
```

`--local` 先在安装脚本旁找包，再查找相对于脚本的 `../target/packages-0.12.0/`，并跳过联网更新索引。如果压缩包已移动或改名，加 `--archive /实际路径/包文件`，三个验签文件留在包旁。要在离线环境运行容器化 app，还需提前准备好相应的 app、依赖和容器镜像。[离线安装选项](install/README-CN.md#0120-起的本地安装)

### 验证安装

按默认路径为个人安装时，先在当前 shell 设置 `PATH`，再查看三个核心命令的版本。要让新终端也能找到它们，把同一行 `export` 加入 shell 配置文件。本版均应报告 `0.12.0`，这一步在离线机器上也能完成。

```sh
export PATH="$HOME/.local/bin:$HOME/.local/share/taffish/bin:$PATH"
taf --version
taffish --version
taffish-mcp --version
```

<a name="release-校验"></a>

官方安装器校验平台包及三个程序各自的 SHA-256。需要强制验证两份清单的签名时，在安装命令后加 `--verify gpg`，并确保本机有 `gpg` 和 `gpgv`。[核对平台包与发布公钥](install/README-CN.md#发布验签)

<a name="基础使用"></a>

## 首次使用

核心命令安装完成、容器后端就绪后，可以先用 FastQC 做一个无需输入数据的示例。前两条命令需要联网访问索引和 app 仓库，安装 app 还需要 Git。最后一条会启动 FastQC，首次运行可能需要下载镜像。

```sh
taf update --user
taf install --user fastqc 0.12.1-r1
taf-fastqc-v0.12.1-r1 -- --version
```

FastQC 应输出 `FastQC v0.12.1`。第一个 `--` 将后面的选项交给 FastQC 本身。若要看 TAFFISH 包的版本和修订号，运行 `taf-fastqc-v0.12.1-r1 --version`。接下来就可以用页首的命令处理自己的数据。[快速开始教程](https://github.com/taffish/taffish-docs/blob/main/zh/quick-start.cn.md)

<a name="升级或移除-taffish"></a>

## 更新与升级

| 想更新什么 | 怎么做 |
| --- | --- |
| TAFFISH 本体（`taf`、`taffish`、`taffish-mcp`） | 重新运行新版安装器，沿用原来的安装范围（`--user` 或 `--system`）和路径。离线升级时，使用新版的签名平台包并加 `--local`。[本体升级说明](install/README-CN.md#升级和移除) |
| 本地 Hub 索引 | 运行 `taf update`，刷新可用 app 及其版本的目录。已安装的 app 保持原版本。 |
| 已安装的 Hub app | 刷新索引后，运行 `taf upgrade` 预览可升级项目，确认后运行 `taf upgrade --yes` 应用升级计划。 |

这两个 Hub 命令默认使用用户范围。维护系统安装的 app 时，刷新索引、预览和执行升级都应使用 `--system`。

## 按需查阅

| 我想做什么 | 从哪里开始 |
| --- | --- |
| 找一个工具或流程 | [浏览 Hub](https://taffish.github.io/) · [在命令行使用 Hub](https://github.com/taffish/taffish-docs/blob/main/zh/taffish-hub.cn.md) |
| <a name="taf-app-smoke-元数据"></a><a name="github-和发布依赖"></a>封装工具或编写流程 | [app 作者指南](https://github.com/taffish/taffish-docs/blob/main/zh/app-developer-guide.cn.md) · [flow 作者指南](https://github.com/taffish/taffish-docs/blob/main/zh/taf-flow-developer-guide.cn.md) · [TAF 脚本教程](https://github.com/taffish/taffish-docs/blob/main/zh/taf-script-tutorial.cn.md) · [app 元数据与冒烟检查](docs/standards/zh-CN/taffish-project-spec.md#smoke) |
| <a name="运行时配置和镜像源"></a><a name="容器后端"></a><a name="docker"></a><a name="podman"></a><a name="apptainer"></a><a name="apptainer-系统级共享-sif-缓存"></a>选容器后端或部署共享服务器 | [Docker、Podman 和 Apptainer](https://github.com/taffish/taffish-docs/blob/main/zh/quick-start.cn.md#容器后端) · [系统安装、镜像源与 SIF 共享缓存](https://github.com/taffish/taffish-docs/blob/main/zh/system-administration.cn.md) |
| <a name="环境诊断"></a><a name="故障排查"></a><a name="找不到-taf-或已安装的-app-命令"></a><a name="taf-update-出现-github-connection-reset"></a><a name="apptainer-提示缺少-mksquashfs"></a><a name="apptainer-提示-no-writable-apptainer-image-directory-found"></a><a name="apptainer-每次运行都输出-converting-sif-file-to-temporary-sandbox"></a><a name="docker-permission-denied"></a>排查命令或安装故障 | 用 `taf doctor --user` 诊断本地环境。[故障排查](https://github.com/taffish/taffish-docs/blob/main/zh/troubleshooting.cn.md) · [升级或卸载 TAFFISH](install/README-CN.md#升级和移除) |
| <a name="cli-人类语言"></a><a name="shell-自动补全"></a><a name="vim-语法高亮"></a>配置 shell 或 CLI 显示语言 | `taf config language zh` 或 `taf config language en`。[语言设置与语言包](docs/standards/zh-CN/localization.md) · [Shell 补全](completion/README.md) · [Vim 语法高亮](vim-highlight/README.md) |
| <a name="mcp--ai-集成"></a>接入 AI 客户端 | [MCP 客户端配置](https://github.com/taffish/taffish-docs/blob/main/zh/mcp-clients.cn.md) · [MCP 工具与权限](docs/standards/zh-CN/mcp-interface-spec.md) |
| <a name="从源码构建"></a>从源码构建或参与开发 | [源码构建](docs/dev/zh-CN/build-from-source.md) · [开发文档](docs/README.zh-CN.md) · [贡献指南](CONTRIBUTING.md) |

<a name="许可证"></a>

TAFFISH 源码采用 [Apache License 2.0](LICENSE)。官方二进制还包含各平台运行时，适用[对应声明与条款](install/README-CN.md#运行时许可)。[报告安全问题](SECURITY.md)
