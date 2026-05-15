# TAF 语言规范草案

本页记录 TAF 语言的规范草案。它比 [TAF 语言契约](taf-language-contract.md) 更具体，但仍以当前参考实现为准。

## 规范状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 行类型、`ARGS`/`RUN`、子标签、参数 token | Draft v0.1 稳定 | 已由 lexer/parser/binder/compiler 共同实现。 |
| `han.args` 参数规格嵌入 | Draft v0.1 稳定 | TAF 依赖 `han.args` 解释具体参数语义。 |
| `<shell>` 与容器标签 | Draft v0.1 稳定 | 是当前 taf-app 的主要执行模型。 |
| `<taffish>` 内联组合语法 | Experimental | 已有实现基础，但完整语言边界仍需 hub/flow 案例验证。 |
| `taf-app` 命令模式 | Experimental | 当前可用，但用户可见语义仍可能细化。 |

## 文件模型

TAF 文件是一个文本文件。当前 lexer 支持 LF、CRLF 和 CR 换行。编译器把 TAF 源码转换为 shell 脚本，运行时行为由标签对应的 emitter 决定。

一个 TAF 文件最终被解析为：

1. 参数规格。
2. 一个或多个运行 block。
3. 编译上下文。
4. 绑定后的参数结果。

## 行类型

lexer 将每一行归为以下类型：

| 行类型 | 识别规则 | 说明 |
| --- | --- | --- |
| 空行 | 去掉空格和 tab 后为空 | 可保留在 block 中。 |
| 注释 | 去掉空格和 tab 后以 `#` 开头 | 可保留在 block 中。 |
| `ARGS` 主标签 | 去掉空格和 tab 后等于 `ARGS` | 参数定义区开始。 |
| `RUN` 主标签 | 去掉空格和 tab 后等于 `RUN` | 运行区开始。 |
| 子标签 | 去掉空格和 tab 后形如 `<...>` | 选择 emitter 或定义参数。 |
| 普通代码 | 其他行 | 交给当前 block 或子标签处理。 |

主标签只能是 `ARGS` 或 `RUN`。子标签的内容可以包含文本 token 和参数 token。

## 文件规范化

为了让简单 TAF 更易写，parser 会进行规范化：

1. 如果第一个有效行是子标签，则自动在前面补 `RUN`。
2. 如果第一个有效行是普通代码，则自动补 `RUN` 和 `<taffish>`。
3. 空文件不可编译。

例如：

```taf
echo hello
```

等价于：

```taf
RUN
<taffish>
echo hello
```

这种便利是语言体验的一部分，但复杂 taf-app 应优先写出显式结构。

## ARGS block

`ARGS` block 用于定义参数规格。其结构为：

```taf
ARGS
<(--/-n)name>
World

<!(--/-i)input>
```

在 `ARGS` block 中：

1. 每个子标签头表示一个 `han.args` 参数规格。
2. 子标签下方的普通代码行会被合并为默认值。
3. 默认值中的 `::arg::` token 会转换为 `@{arg}` 形式，交给 `han.args` 默认表达式系统处理。
4. `ARGS` 子标签头不能包含 `::...::` 参数 token。
5. `ARGS` 可以为空，但存在死参数检查。

参数规格的完整语义由 `han.args` 定义。TAF 只负责提取和传递规格。

## RUN block

`RUN` block 描述执行逻辑。其结构为：

```taf
RUN
<shell>
echo hello

<container:ghcr.io/taffish/demo:0.1.0-r1>
demo --help
```

在 `RUN` block 中：

1. 每个子标签开启一个运行 block。
2. 子标签头选择对应 emitter。
3. 子标签下方的普通代码行作为 emitter 输入。
4. 空行和注释可以进入 block。
5. 非空子标签必须有内容；空运行子标签是错误。

同一个文件最多只能有一个 `ARGS` block 和一个 `RUN` block。`ARGS` 必须出现在 `RUN` 之前。

## 参数 token

TAF 使用 `::...::` 表示参数 token，例如：

```taf
echo "sample: ::sample::"
```

lexer 对参数 token 的处理规则：

1. `::` 开始，后续第一个未转义 `::` 结束。
2. 未闭合参数 token 是错误。
3. 参数 token 内部字符串会交给 `han.args:parse-arg-spec` 解析。
4. 参数 token 保留行号和列号，用于错误定位。

支持的 TAF 层转义包括：

| 写法 | 值 |
| --- | --- |
| `\:` | `:` |
| `\<` | `<` |
| `\#` | `#` |
| `\\` | `\` |

其他反斜杠序列按普通文本保留。

## 内置参数

以下参数名由上下文提供，未在 `ARGS` 中声明也可以使用：

| 参数 | 来源 |
| --- | --- |
| `*USER*` | `taf-context-user` 或绑定系统。 |
| `*HOMEDIR*` | `taf-context-homedir` 或绑定系统。 |
| `*WORKDIR*` | `taf-context-workdir` 或绑定系统。 |
| `*LOADDIR*` | `taf-context-loaddir`。 |
| `*ARGV*` | `taf-context-argv`。 |
| `*CMD*` | `taf-context-cmd`。 |
| `*CPUS*` | `taf-context-cpus`。 |
| `*CONTAINER*` | `taf-context-container`。 |

这些名字属于 TAFFISH 保留命名空间。普通参数不应使用 `*...*` 命名风格。

## 绑定与错误

编译流程应保持：

```text
lex-taf -> parse-taf -> bind-taf -> compile-taf-result
```

职责边界：

1. lexer 负责行分类、token 化和位置记录。
2. parser 负责结构化、参数规格提取和静态检查。
3. binder 负责将真实输入绑定到参数规格。
4. compiler 负责参数替换和 emitter 调用。
5. emitter 负责特定标签语义。

parser 不应直接读取真实 CLI 参数，compiler 不应重新解释 `ARGS` block。

## 子标签与 emitter

子标签头会交给 emitter registry 匹配。当前内置标签包括：

| 标签 | 语义 |
| --- | --- |
| `<shell>` | 直接输出 shell 行。 |
| `<taffish>` | TAFFISH 内联/组合执行。 |
| `<taf-app:...>` | taf-app 包装模式，继续交给后续标签。 |
| `<container:IMAGE>` | 按可用后端选择 Docker/Podman/Apptainer。 |
| `<docker:IMAGE>` | 指定 Docker。 |
| `<podman:IMAGE>` | 指定 Podman。 |
| `<apptainer:IMAGE>` | 指定 Apptainer。 |
| `<docker/podman:IMAGE>` | 从给定后端列表中选择可用后端。 |

container tag 可以在 `$` 后传入 runtime arguments。旧的 `$ARGS` 会应用到所有选中后端。
结构化 `$@[backend: ARGS]` block 只会应用到匹配后端：

```taf
<container:IMAGE$@[all: --network host][docker: --gpus all][apptainer: --nv]>
```

结构化 target 包括 `all`、作为 `all` 别名的 `container`、`docker`、`podman`、
`apptainer`，以及 `docker/podman` 这样的 `/` 组合。runtime 参数会在 backend
选择之后再筛选，所以同一个通用 `<container:...>` tag 在 context 或
`TAFFISH_CONTAINER_BACKEND` 强制不同后端时，可能编译出不同的 final run args。

未知标签由 emitter registry 决定是否报错。

## 未稳定区域

以下内容仍应视为草案：

1. `<taffish>` 的完整组合语法。
2. `[[taf:...]]` 流程依赖引用与语言核心之间的正式关系。
3. `taf-app` 命令模式的用户可见语义。
4. 子标签头中的动态参数 token 是否应长期支持。
5. 跨平台 shell 兼容边界。
