# han.args 总览

`han.args` 是 TAFFISH 参数系统的基础。TAF 的 `ARGS` 块、inline `::arg::` 引用、内置变量绑定，最终都依赖 `han.args` 的规格解析和绑定结果。

## 作用

`han.args` 解决三类问题：

1. 把命令行 argv 解析为 token 和 segment。
2. 把参数规格字符串解析为结构化 `arg-spec`。
3. 把输入与规格绑定，生成 `args-result`。

它本身不理解 TAF 文件，也不生成 shell。

## 核心链路

```text
raw argv
  -> parse-args-input
  -> args-input

spec strings
  -> parse-arg-spec
  -> parse-args-spec
  -> args-spec

args-input + args-spec + builtin bindings
  -> bind-args
  -> args-result
  -> get-arg
```

## 核心结构

| 结构 | 作用 |
| --- | --- |
| `arg-token` | argv 中的低层 token。 |
| `arg-segment` | 按 slot 切分的 token 位置组。 |
| `args-input` | argv 解析结果。 |
| `arg-diagnostic` | warning 或 error。 |
| `arg-spec` | 单个参数定义。 |
| `args-spec` | 命令级参数定义集合。 |
| `arg-binding` | 单个参数最终绑定结果。 |
| `args-result` | 整体绑定结果。 |

## 参数类型

`han.args` 当前支持：

| arity | 意义 |
| --- | --- |
| `:flag` | boolean flag，出现即 true。 |
| `:single` | 单值参数。 |
| `:block` | slot block 参数。 |
| `:position` | 位置参数。 |

## TAFFISH 中的使用位置

| TAFFISH 模块 | 使用方式 |
| --- | --- |
| `taffish-core/parser.lisp` | 把 ARGS block 和 inline args 转成 `args-spec`。 |
| `taffish-core/input.lisp` | 把 CLI args 转成 `args-input`。 |
| `taffish-core/binder.lisp` | 调用 `bind-args` 并加入内置变量。 |
| `taffish-core/compiler.lisp` | 通过 `get-arg` 解析 `::arg::`。 |
| `taf-core/project/new.lisp` | 用 `han.args` 解析 `taf new` 参数。 |

## 维护原则

`han.args` 的返回结构是 TAFFISH 多层共享契约。修改时应：

1. 保持 warning/error diagnostic 的可解释性。
2. 不引入 TAF 专属概念。
3. 不直接读取项目配置。
4. 不依赖 shell 或容器后端。
5. 修改 spec 语法时同步更新 TAF 参数标准。
