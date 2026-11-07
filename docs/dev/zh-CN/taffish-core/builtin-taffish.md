# taffish emitter

`emitter/builtins/taffish.lisp` 实现 `<taffish>` 标签。它支持在 TAF 的 shell 内容中内联调用其他 taf-app，并把这些调用先编译成临时脚本。

## 作用

`taffish` emitter 是 TAFFISH 组合能力的重要入口。它让一个 TAF 可以引用另一个 taf-app：

```taf
RUN
<taffish>
[[taf: taf-example --input x ]] | other-command
```

生成 shell 时，`[[taf: ...]]` 会被替换成临时脚本路径。

## 匹配规则

只有 tag 与 `taffish` 大小写不敏感相等时匹配。

## 内联语法

当前识别：

```text
[[taf: ...]]
```

在普通文本中可以用：

| 原始文本 | 含义 |
| --- | --- |
| `\[` | 普通 `[` |
| `\]` | 普通 `]` |

代码行中的 `[[taf: ...]]` 没有闭合或内部为空时，会抛 `taffish-error`。完整源码
注释行（首个非 SPACE/TAB 字符为 `#`）则原样保留，不扫描内联标记，也不解码括号
转义；带缩进的注释、空内容或未闭合内联样式文本同样不会产生子命令编译步骤。

对于 compiler 生成的行，`%scan-inline-parts` 扫描经过既有 TAF 转义处理的源码文本
token。参数片段不参与结构扫描，即使为空或含有引号、`[[taf:`、`]]` 也一样。调用
内部，源码中的单/双引号及反斜杠转义可以保护结束标记 `]]`。标记不能跨越参数片段。
调用仍限于单行，可以和管道及其他文本共存；这不是完整 shell 解析器，也不支持内联嵌套。

扫描器保留命令内容，随后仍使用替换后的文本校验前缀和处理 `--compile`。普通文本
的括号转义解码继续保留，与调用边界识别分开。旧的 `:line/:number` 输入若不含来源
元信息，则直接扫描提供的文本，并从中识别完整注释行。不完整或不一致的元信息会报错，
注释行也不例外。带源码信息的行不会因参数替换值含 `#` 而改变分类；这里不解析普通
代码后的尾部 shell 注释，其中的内联标记仍可能被扫描。

## 命令约束

内联 taf 命令必须以 `taf-` 开头。`%sure-compiled` 会确保命令带有 `--compile`：

| 输入 | 输出 |
| --- | --- |
| `taf-x` | `taf-x --compile` |
| `taf-x a b` | `taf-x --compile a b` |
| `taf-x --compile a b` | 保持不变 |

命令名和首个选项都接受 SPACE 或 TAB 分隔。例如 `taf-x<TAB>a` 变为
`taf-x --compile a`，`taf-x<TAB>--compile<TAB>a` 则保持不变（`<TAB>` 表示
一个制表符）。也接受混合分隔符；插入时可规范化新增首选项两侧的分隔，其余参数文本
和 shell 展开语义保留。这不是 shell 分词或统一引用处理。

如果命令不是 `taf-` 开头，会抛 `taffish-error`。

## 生成逻辑

emitter 会生成临时目录：

```sh
taffish_tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/taffish.XXXXXX") || exit 1
trap 'rm -rf "$taffish_tmpdir"' EXIT INT TERM HUP
```

每个内联 taf app 会被编译为：

```text
$taffish_tmpdir/step-N-taf-xxx.sh
```

然后原始行中的 `[[taf: ...]]` 会替换成对应脚本路径。

生成的 block 先在前置部分编译这些步骤，再执行正文。前置部分在生成的 shell 被执行
时才运行，编译 TAF 或构建项目 wrapper 不运行它。完整源码注释行不会在前置部分增加
步骤，与 `taf check/build` 的依赖发现一致。因此正文中的变量赋值在子步骤编译时点
尚未执行。延迟 shell 文本展开、父子参数块转发，见
[参数替换、转发与展示](../../../standards/zh-CN/argument-passing.md)。
子命令编译失败时，使用独立 shell 引用的 `printf` 将提示写到 stderr，并以 1 退出，
不会再次求值提示中的命令文本。这不意味着普通参数的原始替换具有输入净化能力。

## 实现细节

`*taf-apps-count*` 和 `*all-taf-apps*` 是 special variable，并在 `emit-taffish` 中动态绑定，避免不同 block 之间互相污染。

私有边界扫描器没有计数或参数绑定副作用。`taf check/build` 在原始源码片段上复用
该扫描器来发现依赖，不解析参数值，也不执行 app。

## 设计边界与取舍

compiler 在既有参数替换过程中保留源码 token 和已替换片段，因此 emitter 可以知道
哪些文本能作为调用分隔符，而不必再次求值默认值或参数查询。内部行记录见
[编译流程](compiler.md)。

只有边界识别使用这些来源信息。命令校验、emitter 选择、参数替换、子命令预编译时机
和临时脚本清理仍各司其职。不增加统一引用步骤，也不因值看起来已有引号而例外处理：
普通参数、参数块 token、`*ARGV*` 和命令模式分别保留原有约定。

明确的兼容性取舍是：在带源码信息的路径中，替换数据不再能引入一个完整内联调用，
开发者必须把分隔符写在源码里。相应地，数据中的引号或 `]]` 不再改变调用边界。
这不会让原始 shell 文本替换适用于任意不可信输入，也不能让采用原始文本的子层
自动保留父层的 argv 列表。

[emitter API](../api/emitter-api.md) 仍接受旧的两字段行记录。没有源码来源信息时，
只能扫描提供的文本，不能保证只从源码识别边界。新增元信息限于内部使用，不增加
CLI 选项或 MCP 字段。依赖扫描遵循同一边界规则，但不推断由参数拼接出的命令名。

## 修改指南

修改 taffish emitter 时要谨慎处理：

1. 临时目录清理。
2. `--compile` 注入逻辑。
3. inline token 的 line 和 column。
4. shell quoting。
5. 多个 `[[taf: ...]]` 在同一 block 中的编号稳定性。

这部分是未来高级 workflow 组合的核心，不应和单个 app 的业务逻辑耦合。
