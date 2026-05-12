# taffish-core 编译管线

本页说明 `.taf` 源码如何经过 `taffish-core` 变成 shell。

## 作用

编译管线的目标是把 TAF 的语义拆成多个清晰阶段。每个阶段只解决一种问题，并把结果交给下一阶段。

这样做的好处是：

1. 错误更容易定位。
2. 每一层的输入输出更稳定。
3. 未来增加新的标签、参数能力或容器后端时，不需要重写整个编译器。

## lexer

`lexer.lisp` 接收 TAF 文本，输出 `taf-line` 列表。

它负责识别：

1. 空行。
2. 注释行。
3. 标签行。
4. 普通代码行。
5. `ARGS`、`RUN`、子标签等行类型。
6. TAF 中需要保留的转义和位置信息。

lexer 应该尽量保留原始信息，让后续阶段可以产生准确错误信息。

## parser

`parser.lisp` 接收 `taf-line` 列表，输出 `taf-program`。

它负责：

1. 识别 `ARGS` 块。
2. 识别 `RUN` 块。
3. 把裸代码规范化为默认运行块。
4. 把前导子标签规范化为运行块。
5. 把 ARGS 定义转换为 `han.args` 参数规格。
6. 检查死参数、非法块和结构错误。

parser 的输出应该足够完整，使 binder 不需要再理解源码文本结构。

## input

`input.lisp` 接收外部输入，输出规范化后的 args 和 context。

它处理：

1. CLI 参数输入。
2. 用户、home、工作目录、加载目录。
3. argv、cmd、cpus。
4. 容器后端、挂载、SIF 目录、heredoc 等运行上下文。

这里的重点是把外部世界整理成稳定结构，避免 compiler 直接面对杂乱环境。

## binder

`binder.lisp` 接收 `taf-program`、args 和 context，输出 `taf-result`。

它负责：

1. 绑定用户参数。
2. 注入内置变量，例如 `*USER*`、`*HOMEDIR*`、`*WORKDIR*`、`*LOADDIR*`、`*ARGV*`、`*CMD*`、`*CPUS*`、`*CONTAINER*`。
3. 处理 `taf-app` 命令模式下的特殊参数行为。
4. 形成 compiler 可直接消费的结果。

binder 是语义绑定层。它不应该重新切分源码，也不应该生成最终 shell。

## compiler

`compiler.lisp` 接收 `taf-result` 或 `taf-program`，输出 shell 字符串。

它负责：

1. 解析 token 和绑定值。
2. 把 program block 转换为 emitter block。
3. 调用 `emit-block`。
4. 组合 shebang、prelude、block 输出和 finalize。

compiler 是流程组织者，不应该变成所有标签的具体实现位置。

## 修改风险

最容易出错的地方是阶段边界滑动。例如：

1. 在 parser 中读取真实用户参数。
2. 在 binder 中重新解释 TAF 源码格式。
3. 在 compiler 中写死某个具体标签的行为。
4. 在 emitter 中依赖 parser 的内部临时实现细节。

如果出现这些情况，应优先考虑是否需要新增明确的中间结构或 helper，而不是让某一层直接跨界。
