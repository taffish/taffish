# 参数替换、转发与展示

[English](../en/argument-passing.md)

本文说明当前实现。TAF 将文本编译为 POSIX shell，不同替换形式并不都等价于 argv
列表。选择写法时，需要区分下一层需要的是 shell 源码、多个参数，还是供人阅读的
展示文本。这不是新增的引用模式，也不是自动安全保证。

## 四种路径

| 形式 | 插入生成 shell 的内容 | 作者需要负责的部分 |
| --- | --- | --- |
| 普通 `::input::` | 参数值的文本，不自动添加 shell 引号。 | 选择合适的 shell 位置，明确允许的输入。 |
| 传入参数块的 `::(@:)step::` | 对每个参数 token 分别编码，再用空格连接。 | 作为不带外层引号的参数列表片段，交给下一层 shell 解析。 |
| `::*ARGV*::` | 将 context argv 用空格连接，不逐项编码。 | 将它视为 shell 文本，而非透明的 argv 转发。 |
| `<taf-app:...>` 命令模式 | 将 context argv 用空格连接，替代原 block 内容。 | 将它视为 shell 命令；即使原内容没有 `*ARGV*`，也是如此。 |

参数块编码针对的是解析得到的 token 列表。没有传入参数块时，其字符串默认值是
文本，而不是传入的列表。逐 token 编码在 v0.10.1 中已经存在，并非 v0.11.0 新增。

## 参数到达 TAFFISH 之前

调用端 shell 会先去掉语法引号，并完成自己的展开：

```sh
taffish ./args.taf @step: "$HOME" '$HOME'
```

TAFFISH 收到的第一个值是 home 目录，第二个值是字面文本 `$HOME`，不会保留用户
最初选择了哪种引号。双引号内部的单引号不能阻止展开：`"'$HOME'"` 的值是展开后的
home 目录，两侧带有作为普通字符的单引号。

## 普通参数：文本替换

将以下示例作为 `scalar.taf`：

```taf
ARGS
<!(--/-i)input>
RUN
<shell>
printf '<%s>\n' "::input::"
```

编译并运行：

```sh
taffish ./scalar.taf --input 'sample A.fa' > scalar.sh
sh -n scalar.sh
sh scalar.sh
```

生成的命令为 `printf '<%s>\n' "sample A.fa"`，输出一个值 `<sample A.fa>`。
如果去掉作者写的双引号，这个例子会输出两个值 `<sample>` 和 `<A.fa>`。

这层引号适用于示例中的空格，并非任意输入的通用保护。如果传入值是 `$HOME`，
`"::input::"` 会生成 `"$HOME"`，在运行生成的 shell 时展开。输入中的引号、命令替换
也可能改变解释方式。不要把原样文本替换当作不可信数据的转义机制。

## 参数块：转发多个参数

将以下示例作为 `args.taf`：

```taf
ARGS
<(@:)step>
RUN
<shell>
printf '<%s>\n' ::(@:)step::
```

```sh
taffish ./args.taf @step: --out 'hello world' '$HOME' "a'b" > args.sh
sh -n args.sh
sh args.sh
```

生成的命令为：

```sh
printf '<%s>\n' --out 'hello world' '$HOME' 'a'\''b'
```

运行结果为：

```text
<--out>
<hello world>
<$HOME>
<a'b>
```

`--out` 不需要引用，其余写法用于编码单个 shell 参数。`'a'\''b'` 表示的值是
`a'b`，并不是给实际值增加了引号。参数中如果包含字面 `"$threads"`，这条路径会
保留这些字符；看起来已经带引号的参数不会跳过编码。

### 展示与转发不同

假设传入的两个参数为 `--out` 和 `hello world`：

```taf
printf '<%s>\n' ::(@:)step::
printf '%s\n' "Add: ::(@:)step::"
```

第一行将两个参数分别传给 `printf`。第二行生成：

```sh
printf '%s\n' "Add: --out 'hello world'"
```

输出为 `Add: --out 'hello world'`。外层双引号内部的单引号只是普通字符，这种展示
文本不是 argv 列表。

给整个参数块套双引号，不是通用的展示或转发编码。例如，传入字面 `$HOME` 后，
块片段为 `'$HOME'`；再把片段放进双引号，反而会使 `$HOME` 展开。要展示实际的值，
并区分零个参数和一个空参数，可以使用 shell 位置参数：

```taf
set -- ::(@:)step::
printf 'argc=%s\n' "$#"
for arg do
    printf '<%s>\n' "$arg"
done
```

这会替换生成脚本中的 shell 位置参数，只在符合预期的位置使用。循环逐项显示值，
不会把值再次作为源码解析。只用带 `%s` 格式的 `printf`，即使没有参数也可能输出
一个空值。不要用 `eval` 解码展示文本。

## `*ARGV*`：现有的 shell 文本语义

当 context argv 为 `("sample A.fa" "out dir")` 时：

```taf
printf '<%s>\n' ::*ARGV*::
printf '%s\n' "::*ARGV*::"
```

生成：

```sh
printf '<%s>\n' sample A.fa out dir
printf '%s\n' "sample A.fa out dir"
```

第一行收到四个值。第二行展示一条连接后的字符串，已有的 `"::*ARGV*::"` 用法保持
不变，但它不保留最初参数边界，也不对任意输入进行转义。双引号内的 shell 展开仍然有效。

如果入口由作者控制，并使用不带外层引号的 `::*ARGV*::` 转发 shell 文本，那么需要
让预期的 shell 引号作为实际字符通过调用端 shell。假设 `forward.taf` 为：

```taf
<shell>
printf '<%s>\n' ::*ARGV*::
```

编译时使用：

```sh
taffish ./forward.taf "'sample A.fa'" "'out dir'"
```

生成片段为 `'sample A.fa' 'out dir'`，下一层 shell 将其解析为两个值。这是在有意
传递 shell 源码，不是通用的数据接口。不要给参数块照搬这一层额外引号：参数块会
把引号本身作为数据保留下来。

## taf-app 命令模式

假设 `entry.taf` 为：

```taf
<taf-app:shell>
printf '%s\n' DEFAULT
```

当 context 的第一个参数非空白、且不以 `-` 开头时，命令模式会替换原内容。例如：

```sh
taffish ./entry.taf printf "'<%s>\n'" "'sample A.fa'"
```

生成 `printf '<%s>\n' 'sample A.fa'`，执行后输出 `<sample A.fa>`，不会输出
`DEFAULT`。如果仅传入 `"sample A.fa"` 而没有字面的内层引号，空格连接时会丢失
这一参数边界。若第一个参数以 `-` 开头，则仍使用原 block 内容。

## 父子 Flow

每一层负责自己的输入和输出契约。父 Flow 提供 token 参数块，子 Flow 也以 token
参数块接收和转发时，含空格、空字符串、字面引号及类似分隔符的参数可以跨越多层，
不要求用户为每层额外加引号：

```taf
ARGS
<(@:)step>
RUN
<taffish>
[[taf: taf-child @step: ::(@:)step::]]
```

这里假设 `taf-child` 同样声明并使用 `step` 参数块。如果子 Flow 改用 `*ARGV*` 或
命令模式拼接输入，这一层就切换成了 shell 文本语义；父层的参数块不能挽回之后丢失的边界。

`[[taf: ...]]` 内联调用的编译位于生成 block 的前置部分，先于 block 正文执行。
现有的 shell 文本命令入口可以有意将展开延迟到编译后的子命令执行时：

```taf
<taffish>
threads=7
export threads
[[taf: taf-child-command echo '"$threads"' ]]
```

这里要求 `taf-child-command` 使用 shell 文本命令模式。它的编译器收到字面
`"$threads"`，生成的命令稍后读取导出的变量。如果把 `'"$threads"'` 改为
`"$threads"`，就会在子命令编译时展开，早于正文中的赋值。把同样文本传入 token
参数块则是另一种语义：它是字面数据，不是延迟执行的表达式。

## 内联边界由源码决定

对从源码编译的 `<taffish>` 行，只有源码文本决定 `[[taf:` 的开始与 `]]` 的结束。
替换进来的参数值，包括字符串默认值，不能创建调用、提前结束调用或改变扫描器的
引号状态。例如：

```taf
[[taf: taf-child @step: ::(@:)step::]]
[[taf: taf-child @step: 'literal]].fa' ]]
```

第一行接收的 `sample]].fa`、`[[taf: taf-fake]]`、`both ' and "` 和空字符串仍然是
参数。第二行源码引号内的结束标记也是数据。直接在源码里写未引用的 `sample]].fa`
仍会在第一个 `]]` 结束调用；这种源码参数应加引号。

这只是边界识别规则，不是新的参数引用规则。边界确定后，仍对替换后的命令检查
`taf-` 前缀。命令名和首个选项都接受 SPACE 或 TAB 分隔；除非首个选项已经是
`--compile`，否则在命令名后立即插入它，其余 shell 文本保留。普通参数仍是原始文本，放置不当仍可能
导致 shell 语法错误或改变实际执行。失败提示单独进行 shell 引用，不会再次求值命令文本。

内联调用仍限于单行，允许同一行多个调用、管道和其他 shell 文本，不支持内联嵌套，
也不是完整的 shell 解析器。调用外如需字面标记，使用 `\[[taf: ...]]`；仅加普通
shell 引号不会禁用源码中的开始标记。普通文本原有的 `\[`、`\]` 解码仍然生效，
包括普通文本位置替换进来的参数。

完整源码注释行，即首个非 SPACE/TAB 字符为 `#` 的行，原样保留，不扫描内联调用，
也不进行括号转义解码。注释中的已闭合、空内容和未闭合内联样式标记都不会创建子命令
编译步骤，也不会引发内联语法错误。这由源码行类型决定：替换值中的 `#` 不能把代码行
变为源码注释。普通代码后面的尾部 shell 注释不属于这条完整行规则，其中的内联标记
仍可能被扫描。

兼容边界：从源码编译时，通过 `::arg::` 拼出完整内联调用不再创建调用。应把标记
写在源码里，只替换内部命令内容。仅传入 `:line/:number` 的旧 `emit-block` 调用，
包括动态提供命令的 `<taf-app:taffish>` 命令模式，没有源码元信息，继续按文本扫描边界，
完整注释行也从该输入文本识别。
`taf check/build` 使用同一套源码边界发现依赖，不求值参数，也不推断动态命令名。

## 空参数与剩余限制

CLI 接受空值，并区分空值与缺少值：`--input ""` 是提供空值，末尾只有 `--input`
而没有值仍是错误。`@step: ""` 输出 `''`，在不额外套引号的参数块位置保留一个空参数；
没有传入块参数时，不产生参数。

原始文本路径不会自动补引号：空普通参数或空 `*ARGV*` 文本只插入零个字符。
因此 `"::input::"` 或 `"::*ARGV*::"` 可以产生一个空 shell 参数，而不加引号时没有参数。
命令模式也保留空格拼接行为。将两个字符组成的 shell 片段 `"''"` 通过原始文本传入，
可以产生空 shell 参数；通过参数块传入，则是两个字面的单引号。

执行前应查看生成的 shell，并检查 `sh -n`。语法检查通过并不代表数据安全或展开
时机正确。本文示例针对普通 POSIX shell；容器 heredoc 等 emitter 会引入自己的
引用上下文，需要另行检查。

## 回归测试

`taffish-core/test.lisp` 记录替换规则。
`test/taffish/argument-contract.py` 使用交付二进制进行真实 shell 执行，检查参数
数量和内容、多层编译及延迟展开：

```sh
./test/run-tests.sh --filter taffish/argument-contract
```

`empty-arguments`、`inline-boundaries`、`inline-error-message` 和 `nested-blocks`
检查实际参数数量和内容、生成的 shell 语法、延迟展开以及不求值的错误提示。
另外，`--filter taf-project/inline-source-boundaries` 检查同一组输入下的依赖发现、
实时编译和构建后的 wrapper。

`inline-separators`、`inline-comments`、`inline-projects` 和 `inline-mcp` 覆盖
SPACE/TAB 组合、注释标记、子命令 argv 以及 compile/build 边界。无害的本地子命令
探针检测是否误入运行分支；MCP 测试在编译请求之外单独执行返回的 shell。这些检查
需要包含修正源码的新构建，不能用修正前冻结的发布载荷代替，见
[测试说明](../../../test/README.md)。
