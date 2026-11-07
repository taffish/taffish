# 生成 shell 契约

TAFFISH 的关键设计之一是把 TAF 编译为 shell。生成 shell 是 TAFFISH 的运行边界，也是可移植性的基础。

## 基本目标

生成的 shell 应尽量满足：

1. 可读。
2. 可执行。
3. 可调试。
4. 可组合。
5. 尽量保持 POSIX shell 兼容。

## 编译输出结构

`compiler.lisp` 负责组织：

1. shebang。
2. prelude。
3. 各 block 的 emitter 输出。
4. finalize。

具体标签的 shell 片段由 emitter 生成。

## Quoting 与路径

shell 输出最容易出错的是 quoting、路径和空格。涉及以下内容时应特别谨慎：

1. 用户输入参数。
2. 工作目录。
3. home 目录。
4. 容器挂载路径。
5. 临时脚本路径。
6. 传给 Docker、Podman、Apptainer 的参数。

不要假设替换过程会自动转义用户或环境中的值。普通参数、`*ARGV*` 和 taf-app
命令模式当前插入的是 shell 文本；传入的 block token 列表才会逐参数编码。作者
需要区分源码文本与数据，并选择合适的插入位置。示例及空参数行为见
[参数替换、转发与展示](argument-passing.md)。从源码编译的 `<taffish>` 调用仅使用
源码确定内联边界，命令校验仍使用替换后的文本，诊断消息单独引用命令文本。这些规则
不会给普通参数、`*ARGV*` 或 taf-app 命令模式增加自动引用。

在 `<taffish>` 中，完整源码注释行原样保留，不产生内联子步骤。有效内联调用的
命令名与参数接受 SPACE/TAB 分隔，子命令以 `--compile` 为首个选项调用。这些
子命令编译操作位于生成 shell 的前置部分；编译 TAF 或构建 wrapper 不执行该部分。

## 容器运行契约

container emitter 是生成 shell 中最复杂的部分之一。它需要协调：

1. 后端选择。
2. 镜像或 SIF。
3. 工作目录。
4. 挂载。
5. heredoc 或单命令执行。
6. 后端差异。

修改 container 输出时，应同时考虑 Docker、Podman 和 Apptainer。

## 调试友好性

生成 shell 不应过度压缩。TAFFISH 的一个优势是编译结果可以被人阅读和调试。为了追求短输出而牺牲可读性，通常不值得。
