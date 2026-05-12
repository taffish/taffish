# binder.lisp

`binder.lisp` 是 parser 和 compiler 之间的语义绑定层。它把静态 `taf-program`、外部输入参数和运行上下文合并成 `taf-result`。

## 作用

parser 只知道 TAF 源码结构，不知道用户这次实际传了什么参数。compiler 需要的是已经可解析的参数值。

binder 的职责就是：

1. 规范化 input args。
2. 规范化 context。
3. 从 context 生成内置变量绑定。
4. 调用 `han.args:bind-args`。
5. 检查参数诊断信息。
6. 输出 `taf-result`。

## 内置变量

`%context-to-builtin-bindings` 会把 context 转换为以下绑定：

| 内置变量 | 来源 |
| --- | --- |
| `*USER*` | `taf-context-user` |
| `*HOMEDIR*` | `taf-context-homedir` |
| `*WORKDIR*` | `taf-context-workdir` |
| `*LOADDIR*` | `taf-context-loaddir` |
| `*ARGV*` | `taf-context-argv` |
| `*CMD*` | `taf-context-cmd` |
| `*CPUS*` | `taf-context-cpus` |
| `*CONTAINER*` | `taf-context-container` |

list 类型的 context 值会被空格连接成字符串，其他非字符串值会通过 `format` 转成字符串。

## taf-app 命令模式

binder 中有一段特殊逻辑用于 `taf-app`：

1. 如果 program 中存在 `<taf-app:...>` block。
2. 且 context 的 argv 第一个元素是非 option 命令。
3. 则认为处于 taf-app command mode。

在这个模式下，`han.args` 产生的 `:missing-required` 诊断会被忽略。原因是 taf-app command mode 会把用户命令委托给下一级 tag，而不是要求当前 TAF 的普通参数都完整出现。

这是 `taf-app` 能作为应用入口的关键机制之一。

## 输出

`bind-taf` 输出 `taf-result`：

| 字段 | 值 |
| --- | --- |
| `program` | 输入的 `taf-program`。 |
| `args-result` | `han.args:bind-args` 的结果。 |
| `context` | 规范化后的 `taf-context`。 |
| `body` | 当前等于 `taf-program-body`。 |
| `diagnostics` | `args-result` 中的 diagnostics。 |

## 错误处理

如果 `han.args` 返回 error 级别 diagnostic，且该 diagnostic 不属于 taf-app command mode 下可忽略的 missing-required，则 binder 会抛出普通 `error`。

后续如果要统一错误体验，可以考虑把这些错误包装为 `taffish-error`，但需要保留 `han.args` 的原始诊断信息。

## 修改指南

修改 binder 时要特别注意：

1. 不要重新解析 TAF 源码。
2. 不要生成 shell。
3. 新增内置变量时同步更新 parser 的 builtin arg 白名单。
4. 修改 taf-app command mode 时同步检查 `emitter/builtins/taf-app.lisp`。
5. 修改 diagnostics 策略时同步检查 CLI 错误输出。
