# han.args 参数规格

`vendor/han/args/spec.lisp` 把紧凑的 spec string 解析为 `arg-spec`，再合并成 `args-spec`。

## 作用

参数规格描述一个命令接受哪些参数、每个参数如何输入、是否 required、是否 hidden、是否有默认值。

TAF 的 ARGS block 最终也会变成这些 spec。

## spec 基本语法

总体形式可以理解为：

```text
[prefix] [(entries)] name [? | =default]
```

常见例子：

| spec | 含义 |
| --- | --- |
| `(--/-n)name=World` | long/short option，默认值 `World`。 |
| `!(--/-i)input` | required single option。 |
| `(--/-v)verbose?` | boolean flag。 |
| `(@:)run` | block/slot argument。 |
| `$1` | 位置参数。 |

## prefix

| prefix | 含义 |
| --- | --- |
| `!` | required。 |
| `%` | hidden。 |

flag 永远是 optional，即使写了 `!` 也会被规范化为 not required。

## entry

entry 可以是：

| entry | kind |
| --- | --- |
| `--input` | long |
| `-i` | short |
| `@run:` | slot |

`--` 会自动补成 `--<name>`。`-` 会自动补成 `-<name首字母>`。`@:` 会自动补成 `@<name>:`。

long/short entry 不能和 slot entry 同时设置。slot entry 的 arity 会变成 `:block`。

## 默认值表达式

default 可以是普通字符串，也可以引用其他参数：

| 写法 | 结构 |
| --- | --- |
| `abc` | `"abc"` |
| `@name` | `(:query "name")` |
| `@{name}` | `(:query "name")` |
| `prefix-@name` | `(:concat "prefix-" (:query "name"))` |

支持的 default 转义：

| 原始 | 值 |
| --- | --- |
| `\@` | `@` |
| `\\` | `\` |
| `\{` | `{` |
| `\}` | `}` |

## args-spec 校验

`parse-args-spec` 会把多个 `arg-spec` 放入 hash table，并做校验：

1. 同名 spec 会合并。
2. long/short/slot entry 不能被不同参数重复使用。
3. positional spec 必须从 `$0` 或 `$1` 开始。
4. positional spec 必须连续。

## 修改指南

修改 spec 语法时要同步检查：

1. `taffish-core/parser.lisp` 如何构造 spec string。
2. `bind.lisp` 是否理解新增 arity。
3. `query.lisp` 是否能解析新增 default expression。
4. 参数文档和 TAF 标准是否需要更新。

不要在 spec 层读取用户真实 argv。spec 层只定义“允许什么”，不处理“这次输入了什么”。
