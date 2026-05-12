# parser.lisp

`parser.lisp` 把 lexer 输出的 `taf-line` 列表转换为 `taf-program`。它是 TAF 静态语义的建立位置。

## 作用

parser 负责回答：

1. 哪些行属于 ARGS。
2. 哪些行属于 RUN。
3. RUN 下有哪些 subtag block。
4. ARGS 如何转换为 `han.args` 参数规格。
5. inline `::arg::` 引用是否对应可用参数。

parser 不读取真实用户输入，也不生成 shell。

## 规范化入口

`%normalize-taf-lines` 会对源码做入口规范化：

| 首个有效行 | 规范化结果 |
| --- | --- |
| `ARGS` 或 `RUN` | 保持原结构。 |
| `<...>` | 自动在前面补 `RUN`。 |
| 普通 code | 自动补 `RUN` 和 `<taffish>`。 |
| 空文件 | 当前抛普通 `error`。 |

这让简单 TAF 可以省略显式 `RUN <taffish>`，但 parser 后续总能看到统一结构。

## ARGS 与 RUN 切分

`%split-args-run` 负责把规范化后的行分成：

1. `args-block`
2. `run-block`

规则包括：

1. `ARGS` 只能出现一次。
2. `RUN` 只能出现一次。
3. 不能在 `RUN` 后再写 `ARGS`。
4. block 内不能出现新的 primary tag。

## subtag block

`%normalize-block-subtags` 把 block 内行按 subtag 分组。结构大致是：

```lisp
((<subtag-line> line line ...)
 (<subtag-line> line line ...))
```

code 行必须出现在某个 subtag 之后。RUN block 中空 subtag 会报错。ARGS block 当前允许空 subtag。

## 参数规格来源

parser 从两处收集参数规格：

1. ARGS block。
2. 所有 inline `::...::` token。

ARGS block 中每个 subtag 的 head 作为参数名，子行内容组合为默认值表达。inline args 会直接作为参数规格进入 `han.args`。

最终 parser 调用：

```lisp
han.args:parse-args-spec
han.args:parse-arg-spec
```

得到统一 `args-spec`。

## dead arg 检查

`%validate-args-used` 会检查 inline arg 是否是“不可设置且没有默认值”的死参数。内置变量不参与这个检查。

内置变量包括：

```text
*USER*
*HOMEDIR*
*WORKDIR*
*LOADDIR*
*ARGV*
*CMD*
*CPUS*
*CONTAINER*
```

这一步能提前发现 TAF 中写了无法由用户或默认值提供的参数。

## 输出

`parse-taf` 输出 `taf-program`：

| 字段 | 来源 |
| --- | --- |
| `source-string` | 原始 TAF 字符串。 |
| `lines` | 规范化后的 `taf-line`。 |
| `args-spec` | ARGS 与 inline args 合成的参数规格。 |
| `body` | RUN block。 |
| `metadata` | 当前为 `nil`。 |

## 当前实现状态

parser 大多数语义错误使用 `signal-taffish-error`，但仍有少量普通 `error`。后续如果要提升错误体验，可以逐步把这些普通错误改成带 line、column、source-string 的 `taffish-error`。

## 修改指南

修改 parser 时要守住三条边界：

1. 不读取 CLI 输入。
2. 不生成 shell。
3. 不把 emitter 专属语义写进 parser。

如果要新增 TAF 语法，先判断它是词法规则、结构规则、绑定规则还是发射规则。不要把所有新能力都塞进 parser。
