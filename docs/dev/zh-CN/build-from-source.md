# 从源码构建

这页说明如何从源码仓库构建 TAFFISH。大多数用户应该使用根 README 中的预构建二进制安装方式；源码构建主要面向贡献者、维护者、打包者，以及需要检查或修改实现的用户。

## 组件

仓库会构建三个命令行入口：

| 命令 | 作用 |
| --- | --- |
| `taffish` | 把 `.taf` 源码编译成 shell code。 |
| `taf` | 管理 TAFFISH 项目、本地 Hub 包、配置、历史和诊断。 |
| `taffish-mcp` | 为 AI 客户端暴露保守的 MCP tools/resources/prompts。 |

主 ASDF system 是 `taffish`。开发/测试 system 是 `taffish.dev`。

## 需求

源码构建的最低需求：

```text
Common Lisp 实现
POSIX shell 工具
Git
```

0.8.0 的维护者构建路径：

| 平台 | 官方二进制构建路径 | 说明 |
| --- | --- | --- |
| macOS Apple Silicon | SBCL | 当前发布的 macOS 二进制依赖 Homebrew `zstd`。 |
| Linux x86_64 | LispWorks | 当前发布的 Linux 二进制由 LispWorks 手动构建。 |

SBCL 构建适合开发和本地测试。当前 Linux release 载荷使用 LispWorks 构建，因为它可以提供较小的运行时依赖面。LispWorks 是商业软件；公开源码仓库不包含 LispWorks 本身。

## 开发加载

加载开发 system：

```sh
sbcl --load load-taffish.dev.lisp
```

在 Lisp image 中运行完整测试：

```lisp
(han.test:run-all-tests)
```

非交互式 SBCL 测试：

```sh
sbcl --load load-taffish.dev.lisp \
  --eval '(han.test:run-all-tests)' \
  --quit
```

## 用 SBCL 构建二进制

把三个可执行入口构建到 `target/`：

```sh
sbcl --load load-taffish.lisp --compile
```

预期本地构建输出：

```text
target/taf
target/taffish
target/taffish-mcp
```

检查生成命令：

```sh
./target/taf --version
./target/taffish --version
./target/taffish-mcp --version
```

这些不带后缀的文件是本地构建输出。维护者发布 release tag 前，会把它们重命名/复制为
`taf-darwin-arm64-0.8.0` 这类版本化文件名。

## 用 LispWorks 构建二进制

LispWorks 构建使用同一个 loader 入口：

```sh
lispworks -build load-taffish.lisp --compile
```

loader 会在 `target/` 下创建三个不带后缀的入口：

```text
target/taf
target/taffish
target/taffish-mcp
```

如果你的 LispWorks 可执行文件名称或路径不同，请直接调用对应可执行文件。仓库不 vendoring 或再分发 LispWorks。

## 手动 release 载荷

0.8.0 release 会把手动构建的二进制载荷保留在 `target/` 下，这样 GitHub 和 Gitee raw 安装器可以从不可变 git tag 下载文件。

0.8.0 维护者 release 载荷包含：

```text
target/SHA256SUMS
target/SHA256SUMS.asc
target/TAFFISH-RELEASE-KEY.asc
```

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

这会校验被签名的 checksum manifest。它不是可复现构建声明，也不是 GitHub Actions artifact attestation。等 release 二进制由自动化流水线生成后，可以再加入这些能力。

## 当前公开 API 边界

`compile-taf-program` 在 0.8.0 中不是完成态公开 API。稳定的用户侧编译路径是 `taffish` 命令，以及 `taffish-mcp` 暴露的 source/file compile tools。除非模块文档明确标为稳定，否则更底层的实验性入口应视为实现细节。
