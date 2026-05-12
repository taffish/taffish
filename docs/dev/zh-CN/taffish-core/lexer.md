# lexer.lisp

`lexer.lisp` 把 TAF 源码字符串转换为 `taf-line` 列表。它是编译链路中第一个理解 TAF 文本结构的模块。

## 作用

lexer 只负责词法层面的识别：

1. 读取逻辑行。
2. 判断行类型。
3. 识别行内 `::arg::` token。
4. 处理 TAF 自己的少量转义。
5. 记录 line 和 column。

它不负责参数语义、RUN/ARGS 分组、默认值解析或 shell 生成。

## 行读取

`%read-taf-line` 支持三种换行：

1. LF
2. CRLF
3. CR

这让 TAF 文件在不同系统换行风格下都能被读取。

## 行分类

`%line-kind-and-subkind` 把 trim 后的行分为：

| 形式 | kind | subkind |
| --- | --- | --- |
| 空行 | `:empty` | `nil` |
| `# ...` | `:comment` | `nil` |
| `ARGS` | `:tag` | `:args` |
| `RUN` | `:tag` | `:run` |
| `<...>` | `:tag` | `:subtag` |
| 其他 | `:code` | `nil` |

注意：`ARGS` 和 `RUN` 必须是 trim 后完全匹配。`<...>` 只有在 trim 后首尾分别是 `<` 和 `>` 时才是 subtag。

## Token 规则

lexer 当前只产生两种 token：

| kind | 含义 |
| --- | --- |
| `:text` | 普通文本。 |
| `:arg` | `::name::` 形式的参数引用。 |

对普通 code 行，lexer 会扫描整行。对 subtag 行，lexer 只扫描尖括号内部，并把 column 设置为原始内容在整行中的位置。

## 转义规则

TAF lexer 只消费以下转义：

| 原始文本 | token value |
| --- | --- |
| `\:` | `:` |
| `\<` | `<` |
| `\#` | `#` |
| `\\` | `\` |

其他反斜杠序列保留为普通文本。这个规则很重要，因为 TAF 最终输出 shell，不能随便吞掉 shell 自己需要的反斜杠。

## 错误情况

lexer 会在这些场景抛出 `taffish-error`：

1. `::arg` 没有闭合。
2. subtag 行结构无效。

`lex-taf` 本身要求输入必须是字符串，否则抛普通 `error`。

## 维护不变量

1. lexer 不做 shell word splitting。
2. lexer 不解析 ARGS 的参数规格。
3. lexer 不判断参数是否存在。
4. lexer 必须尽量保留原始文本和位置。
5. lexer 的输出应足够让 parser 继续工作，不应要求 parser 回头读原始源码。

## 修改指南

如果要新增 token 类型，例如未来支持更复杂的插值语法，需要同步检查：

1. `model.lisp` 中 token kind 的说明。
2. `parser.lisp` 对 inline args 的提取。
3. `compiler.lisp` 中 `%resolve-taf-token`。
4. TAF 语言契约文档。

如果要改变转义规则，必须特别谨慎，因为这会影响已有 taf-app 的 shell 输出。
