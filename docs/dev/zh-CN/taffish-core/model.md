# model.lisp

`model.lisp` 定义 `taffish-core` 跨阶段共享的数据结构和核心错误条件。它是 lexer、parser、binder、compiler、emitter 之间的共同语言。

## 作用

TAFFISH 的编译链路分成多个阶段。如果每个阶段都直接传递临时 plist 或字符串，系统会很快失去结构。`model.lisp` 的作用就是把这些阶段之间传递的对象固定下来。

当前主要结构包括：

| 结构 | 作用 |
| --- | --- |
| `taf-token` | 行内 token，保留原始文本、规范化值、类型和位置。 |
| `taf-line` | 一行 TAF 的结构化结果。 |
| `taf-context` | 本次编译或运行的宿主上下文。 |
| `taf-program` | parser 输出的静态程序。 |
| `taf-result` | binder 输出的已绑定程序。 |
| `taffish-error` | 带 message、line、column、source-string 的核心错误。 |

## 系统位置

```text
model
  -> lexer
  -> parser
  -> input
  -> binder
  -> compiler
  -> emitter
```

`model.lisp` 位于 `taffish-core` 最底层。它不应该依赖 lexer、parser、compiler 或 emitter 的内部逻辑。

## 结构说明

### taf-token

`taf-token` 表示行内最小语义片段。

| 字段 | 含义 |
| --- | --- |
| `raw-string` | 原始文本，例如 `::name::` 或普通文本。 |
| `value` | 规范化后的值。普通文本可能处理转义，arg token 去掉外层 `::`。 |
| `kind` | 当前主要是 `:text` 或 `:arg`。 |
| `line` | token 起始行号，从 1 开始。 |
| `column` | token 起始列号，从 1 开始。 |

### taf-line

`taf-line` 表示一行 TAF。

| 字段 | 含义 |
| --- | --- |
| `raw-string` | 该行原始文本。 |
| `tokens` | 行内 token 列表。tag 行如果是 subtag，会保存 subtag 内部 token。 |
| `kind` | `:empty`、`:comment`、`:tag` 或 `:code`。 |
| `subkind` | `nil`、`:args`、`:run` 或 `:subtag`。 |
| `line-number` | 行号，从 1 开始。 |

### taf-context

`taf-context` 表示运行上下文，不属于用户参数。

| 字段 | 含义 |
| --- | --- |
| `user` | 宿主用户。 |
| `homedir` | 宿主 home。 |
| `workdir` | 工作目录。 |
| `loaddir` | app 或 TAF 加载目录。 |
| `argv` | 用户命令参数列表。 |
| `cmd` | 当前命令名。 |
| `cpus` | CPU 数等资源信息。 |
| `container` | 容器配置 alist。 |
| `extras` | 未知上下文键，供扩展保留。 |

### taf-program

`taf-program` 是 parser 的输出。它仍然是静态对象，尚未绑定真实用户输入。

| 字段 | 含义 |
| --- | --- |
| `source-string` | 原始 TAF 源码。 |
| `lines` | 规范化后的 `taf-line` 列表。 |
| `args-spec` | 从 ARGS 和 inline args 提取出的 `han.args` 参数规格。 |
| `body` | RUN 主体，当前是按 subtag 分组的 block 列表。 |
| `metadata` | 预留元信息。 |

### taf-result

`taf-result` 是 binder 的输出，也是当前 compiler 的主要输入。

| 字段 | 含义 |
| --- | --- |
| `program` | 原始静态程序。 |
| `args-result` | `han.args:bind-args` 的绑定结果，加上内置变量。 |
| `context` | 本次上下文。 |
| `body` | 当前和 `program.body` 同构。 |
| `diagnostics` | 参数绑定诊断信息。 |

## 错误模型

`taffish-error` 带有：

1. `message`
2. `line`
3. `column`
4. `source-string`

核心代码应优先使用 `signal-taffish-error` 抛出可定位错误。当前仍有少量普通 `error`，这些可以在后续逐步统一。

## 修改指南

修改模型层要非常保守：

1. 新增字段前先确认是不是跨阶段共享信息。
2. 修改字段含义时必须检查所有 accessor 调用点。
3. 不要把某个 emitter 的临时信息放进全局模型。
4. 如果新增 token kind 或 line kind，需要同步更新 lexer、parser、compiler 和标准文档。
