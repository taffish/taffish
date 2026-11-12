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

各版本的维护者构建方式

| 平台 | 0.11.0 | 0.12.0 当前准备 |
| --- | --- | --- |
| macOS Apple Silicon | SBCL，运行需 Homebrew `zstd` | 关闭 core 压缩支持的 SBCL，分发为 `.tar.xz` |
| Linux x86_64 | LispWorks | LispWorks，分发为 `.tar.gz` |

0.12.0 的 Apple Silicon 官方包要求 macOS 15 及以上，系统 `tar` 可以直接解包。当前关闭 core 压缩支持的 SBCL 构建只链接 macOS 系统库，无需 Homebrew `zstd`。Linux 安装需要 `tar` 和 `gzip`。安装预构建程序无需安装 Lisp 实现。Linux 维护者从源码重建官方程序时需要 LispWorks。CCL 和 ECL 的开发构建继续保留。每次发布前，两个平台都须核对最终包及签名，完成干净安装和从上一发布版升级的验收。

## 开发加载

仓库随附 [Han Lisp 0.3.0](han/README.md)，它为各 Lisp 实现提供可移植接口，构建时会自动加载。

加载开发 system：

```sh
sbcl --load load-taffish.dev.lisp
```

在 Lisp image 中运行完整测试：

```lisp
(han.test:run-all-tests)
```

使用待测 Lisp 实现运行 TAFFISH 单测，下面保留 CCL 和 SBCL 两种命令。通过项为零或存在失败时，命令返回非零状态。要独立验证 Han，重新启动同一 Lisp 实现，将加载文件改为 `vendor/han/load-han.dev.lisp`。

```sh
ccl --no-init --batch --quiet --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (han.host:quit (if (and (plusp passed) (zerop failed)) 0 1)))'

sbcl --no-userinit --no-sysinit --disable-debugger --load load-taffish.dev.lisp \
  --eval '(multiple-value-bind (passed failed) (han.test:run-all-tests) (han.host:quit (if (and (plusp passed) (zerop failed)) 0 1)))'
```

## 用 ECL 或 Clozure CL 构建开发程序

macOS 上的 CCL 开发程序仍有尚未解决的偶发原生异常。需要正式发行程序时，请使用官方 SBCL 平台包。

在仓库根目录选择本机所用实现的命令。文件名后单独的 `--` 用来把后面的选项传给 TAFFISH。

```sh
# Clozure CL
ccl --load ./load-taffish.lisp -- --compile

# ECL
ecl -shell ./load-taffish.lisp -- --compile
```

两条命令都在 loader 旁生成 `target/taf`、`target/taffish` 和 `target/taffish-mcp`。只构建其中一个时，把 `--compile` 换成 `--compile-taf`、`--compile-taffish` 或 `--compile-taffish-mcp`。再次编译或更换实现时，会替换选中的同名程序。如果 PATH 中没有 `ccl` 命令，可使用 CCL 可执行文件的实际路径，例如 Apple Silicon 上的 `darm64cl`。

ECL 构建需要 Unicode ECL 及配套的 C 编译器、头文件和链接器，CCL 构建需要 64 位实现。项目在 macOS arm64 和 Linux x86-64 上使用 ECL 26.5.5 与 CCL 1.14。需要同时保留两种实现的产物时，可通过原有 shell 脚本为每次构建指定独立的输出目录。

```sh
work=$(mktemp -d)
sh scripts/build-from-source.sh ecl "$work/ecl"
"$work/ecl/bin/taf" --version

# 已安装 Clozure CL 时：
sh scripts/build-from-source.sh ccl "$work/ccl"
"$work/ccl/bin/taffish-mcp" --version
```

脚本在 PATH 中查找 `ecl` 或 `ccl`，也可将环境变量 `ECL` 或 `CCL` 指向具体的可执行文件。构建会在指定目录下生成 `bin/taf`、`bin/taffish` 和 `bin/taffish-mcp`。输出目录应位于源码树之外，可以是空目录或尚不存在的目录，其父目录须存在。每次构建使用独立的编译缓存。

ECL 开发程序使用本机 ECL 安装提供的运行库。在本次验证的 macOS 环境，运行时需要保留安装位置上的 `libecl` 和 GMP。CCL 将内核与应用映像保存为一个可执行文件。普通用户继续安装对应平台的官方二进制即可。

需要同时构建并运行定向回归时，选用另一个空目录。回归还会让两个 `taf run` 进程共用 TMPDIR，核对其中一个非零退出时只清理自己的临时目录。

```sh
sh test/source-build.sh ecl "$work/ecl-check"
# 测试 Clozure CL 时将第一个参数改为 ccl。
```

运行完整外测时，显式指定这次构建的三个程序：

```sh
bin="$work/ecl-check/bin"
sh test/run-tests.sh --taf "$bin/taf" --taffish "$bin/taffish" --taffish-mcp "$bin/taffish-mcp"
```

## 用 SBCL 构建二进制

复现无 zstd 依赖的 macOS 官方构建时，须使用以 `--without-sb-core-compression` 构建的 SBCL。TAFFISH 的 `--compile` 不会移除 SBCL runtime 的依赖；普通 Homebrew 构建可能仍需要 zstd。编译后用 `otool -L` 核对程序依赖。

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

这些不带后缀的文件是本地构建输出。维护者签名及打包前会为它们添加版本化文件名，例如 `taf-darwin-arm64-0.12.0`。

## 二进制冒烟测试

要对仓库内的签名平台包执行二进制冒烟测试，先准备当前平台的安装文件：

```sh
scratch=$(mktemp -d)
bash test/ci-release-payloads.sh "$scratch/release"
test/binary-smoke.sh --target-dir "$scratch/release/target"
```

如果测试的是不带后缀的本地构建输出，可以显式传入路径：

```sh
test/binary-smoke.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

这个测试会检查 `--version`，用 `taffish` 编译并运行一个最小 shell TAF，
用 `taf` 创建/检查/编译一个最小 project，并验证 MCP JSON-RPC 的基础启动
和 tool discovery。它还会检查容器 runtime 参数的编译路径，但不会拉取镜像或
真正运行容器。

如果要运行更完整的外部测试套件：

```sh
test/run-tests.sh --target-dir "$scratch/release/target"
```

这个入口会包含 binary smoke test，并额外运行真实 `taffish` conformance case
以及 project、Hub、system、i18n、MCP、publish 恢复和 installer conformance。

只运行 standalone installer 测试子集：

```sh
test/run-tests.sh --target-dir "$scratch/release/target" --filter installer/
```

这个子集需要在 macOS 和 Linux 都运行。普通用户运行会验证 user scope 和未授权 system
写入拒绝；管理员模式与 sticky shared-cache 的 root-only 分支只使用测试临时路径，可以
通过以下命令选择：

```sh
sudo test/run-tests.sh \
  --target-dir "$scratch/release/target" \
  --filter installer/system-permissions
```

修改 installer 时还必须运行 `install/generate-installers.sh --check`，以及
[安装器手册](../../../install/README-CN.md)列出的语法和静态检查。

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

如果你的 LispWorks 可执行文件名称或路径不同，请直接调用对应可执行文件。使用 LispWorks 构建需要自备已获许可的开发环境；官方 Linux 程序内含其运行时，适用[TAFFISH Linux 运行时条款](../../../licenses/LISPWORKS-RUNTIME.txt)。

## 平台发布包的制作

已发布的 0.11.0 标签提供六个裸程序和签名的 `SHA256SUMS`。0.12.0 的打包配置采用 macOS arm64 上关闭 core 压缩支持的 SBCL，以及 Linux amd64 上的 LispWorks。签名前在各自平台逐个执行 `--version`，核对运行时依赖。正式发布时同步源码与安装器模板的默认版本，重新生成两个安装器。

将发布公钥 `TAFFISH-RELEASE-KEY.asc` 和六个程序放入 `target/`。程序文件名采用 `<程序>-<平台>-<版本>`，例如 `taf-darwin-arm64-0.12.0`。从仓库根目录运行统一的签名与打包入口：

```sh
cd target
./make-sha-asc.sh
```

脚本从六个程序的文件名识别版本，生成并签署 `SHA256SUMS`，核对发布公钥和程序摘要，然后在 `packages-0.12.0/` 生成两个平台包。若同一份清单已有有效发布签名，则沿用该签名并继续打包。多个版本并存时，用 `./make-sha-asc.sh VERSION` 指定版本。无需再运行单独的 `package-release.sh`。

macOS 包还会自动生成每片最多 8 MiB 的传输文件（`.part-aa`、`.part-ab` 等）和有序的 `.parts` 摘要清单，供 Gitee 使用。Linux 仍为一个 `.tar.gz`。完整 macOS 包保留给 GitHub 和本地安装；切分不改变原包字节或既有签名。已有已签包只需补分片时，在 `target/` 运行：

```sh
./make-sha-asc.sh --split-only packages-0.12.0/taffish-0.12.0-darwin-arm64.tar.xz
```

已有分片或传输清单拒绝覆盖。`.parts` 仅是传输元数据，不能代替已签署的整包摘要；此操作不会重新压缩或签名。打包端使用系统 `split`，安装端使用 `cat` 合并。

输出包括 macOS 的 `.tar.xz`、Linux 的 `.tar.gz`、包外清单 `ARCHIVE-SHA256SUMS`、发布公钥，以及用于签署压缩包的第二个 `make-sha-asc.sh`。每包收录本平台三个程序、共用的六程序清单及签名、公钥、补全、Vim 文件和许可证。macOS 包附带 `licenses/SBCL-NOTICES.txt`，Linux 包附带 `licenses/LISPWORKS-RUNTIME.txt`。内层共用清单或签名改变时，两个平台包都要重新生成，即使只替换了 macOS 程序。

签名时为 GPG 和 Pinentry 选择本机可用的 UTF-8 locale，校验和处理仍使用 C locale。打包机使用 `sh`、`tar`、`shasum`、`gpg` 和 `gpgv`。macOS 系统 tar 直接压缩两种格式；使用 GNU tar 的打包机还需 `xz` 和 `gzip`。

脚本不会覆盖已有输出目录。再次制作同版本时，先将旧包另行归档为证据，或指定新的输出路径。签名失败时保留原内层清单和签名，不进入打包；签名成功而压缩失败时，保留有效的新内层签名，不发布半成品包目录。

失败恢复或自动化场景可使用同一脚本的分步模式：

```sh
# 只签署程序清单。
./make-sha-asc.sh --sign-only

# 沿用已签清单，只重试打包。
./make-sha-asc.sh --package-only

# 指定独立输入目录和新的输出目录。
./make-sha-asc.sh "$version" "$payload_dir" "$output_dir"
```

自定义目录参数前须给出版本。显式输出目录必须位于源码和输入目录之外，父目录须已存在。`--sign-only` 可接受版本和输入目录，不接受输出目录。旧 `scripts/package-release.py` 接口转调 `--package-only`，不会签署程序。只更新随附声明时，可用 `--package-only` 复用已验证的程序和内层签名，再签署新包外清单。

进入输出目录，运行其中生成的签名脚本。它按 `ARCHIVE-SHA256SUMS` 核对两个压缩包，再用发布密钥生成 `ARCHIVE-SHA256SUMS.asc`。若该签名已存在，脚本会停止并保留原文件；旧包外签名仅对应其原始清单。

```sh
cd packages-0.12.0
./make-sha-asc.sh
```

直接从 `target/packages-<version>/` 收录两个压缩包、macOS `.parts` 清单及其列出的全部 `.part-*` 文件、`ARCHIVE-SHA256SUMS`、`ARCHIVE-SHA256SUMS.asc` 和 `TAFFISH-RELEASE-KEY.asc`，在 GitHub 和 Gitee 使用同一版本标签及目录。签名助手留在本地。

发布载荷在候选工作树就位后，两平台分别从仓库根目录执行 `bash test/ci-release-payloads.sh "$new_test_dir"` 和 `test/run-tests.sh --target-dir "$new_test_dir/target"`。测试目录使用已有父目录下的新路径。核对同前缀从官方 0.11.0 原地升级，并在发布后测试两个固定标签入口的匿名下载。[安装器说明](../../../install/README-CN.md)

## 当前公开 API 边界

`compile-taf-program` 不是完成态公开 API。稳定的用户侧编译路径是 `taffish` 命令，以及 `taffish-mcp` 暴露的 source/file compile tools。除非模块文档明确标为稳定，否则更底层的实验性入口应视为实现细节。
