# taffish-core

`taffish-core` 是 TAFFISH 的语言核心。它负责把 `.taf` 源码编译为 shell 脚本，是整个系统最核心、最应该保持稳定的一层。

## 作用

`taffish-core` 解决的问题是：如何把一个声明式或半声明式的 TAF 文件，转换为可移植、可检查、可执行的 shell。

它不负责：

1. 从 hub 下载软件包。
2. 管理用户安装目录。
3. 维护 GitHub 或 Gitee 镜像。
4. 决定 app 如何发布。

这些属于 `taf-core` 或更上层生态。

## 系统位置

```text
.taf
  -> taffish-core
  -> shell script
  -> taf-core/project/run 或其他执行入口
```

`taffish-core` 可以被 `taffish-cli` 直接调用，也可以被 `taf-core` 的项目构建、运行流程调用。

## 文件职责

| 文件 | 作用 |
| --- | --- |
| `package.lisp` | 定义并导出核心 API。 |
| `model.lisp` | 定义条件、token、line、context、program、result 等结构。 |
| `lexer.lisp` | 把 TAF 源码切成带位置的逻辑行。 |
| `parser.lisp` | 把逻辑行解析为 `taf-program`，识别 ARGS、RUN 和子标签。 |
| `input.lisp` | 规范化外部参数和运行上下文。 |
| `binder.lisp` | 把参数、上下文和 program 绑定成 `taf-result`。 |
| `emitter/model.lisp` | 定义 emitter 对象和默认生命周期。 |
| `emitter/registry.lisp` | 提供 emitter 注册、匹配、发射机制。 |
| `emitter/builtins/*.lisp` | 内置标签实现，例如 shell、container、taffish、taf-app。 |
| `compiler.lisp` | 组织完整编译流程并生成 shell。 |
| `main.lisp` | 对外封装主要编译入口。 |

## 核心数据结构

`taffish-core/package.lisp` 导出的关键结构包括：

| 名称 | 意义 |
| --- | --- |
| `taffish-error` | TAFFISH 核心错误条件。 |
| `taf-token` | 带原始文本和位置信息的 token。 |
| `taf-line` | TAF 逻辑行。 |
| `taf-context` | 编译和运行上下文。 |
| `taf-program` | parser 输出的程序对象。 |
| `taf-result` | binder 输出、compiler 可消费的绑定结果。 |

这些结构串起了编译链路。维护时应避免让后续阶段回头重新解析前一阶段已经负责过的内容。

## 公开 API

主要 API 包括：

| API | 作用 |
| --- | --- |
| `lex-taf` | 执行词法分析。 |
| `parse-taf` | 执行语法解析。 |
| `normalize-input-args` | 规范化外部输入参数。 |
| `normalize-input-context` | 规范化运行上下文。 |
| `bind-taf` | 执行参数和上下文绑定。 |
| `compile-taf-result` | 从绑定结果生成 shell。 |
| `compile-taf-program` | 内部保留函数；0.9.0 中不导出，且当前未实现。未来公开前需要先明确默认绑定策略。 |
| `compile-taf` | 根据输入类型分发到具体编译函数。 |
| `taffish-to-shell` | 面向外部调用的转换入口。 |

emitter 相关 API 包括：

| API | 作用 |
| --- | --- |
| `*taf-emitters*` | 当前注册的 emitter 列表。 |
| `taf-emitter` | emitter 结构或类。 |
| `register-emitter` | 注册 emitter。 |
| `defemitter` | 定义并注册 emitter 的便利宏。 |
| `emit-block` | 按标签选择 emitter 并生成 shell 片段。 |
| `default-prelude` | 默认编译前置片段。 |
| `default-finalize` | 默认编译结束片段。 |

## 编译不变量

维护 `taffish-core` 时应保护这些不变量：

1. lexer 只做词法和位置标注，不做语义绑定。
2. parser 只处理 TAF 结构和参数规格，不读取用户实际输入值。
3. input 只规范化外部输入和上下文，不解释 TAF 语法。
4. binder 负责把 program 与输入绑定，不重新做词法或语法解析。
5. compiler 负责组织 shell 输出，不直接读取 CLI 参数。
6. emitter 按标签处理块，不应该反向控制 parser。

## 相关专题

- [编译管线](compiler-pipeline.md)
- [Emitter 系统](emitter-system.md)
- [model.lisp](model.md)
- [lexer.lisp](lexer.md)
- [parser.lisp](parser.md)
- [input.lisp](input.md)
- [binder.lisp](binder.md)
- [compiler.lisp 与 main.lisp](compiler.md)
- [emitter registry](emitter-registry.md)
- [shell emitter](builtin-shell.md)
- [taf-app emitter](builtin-taf-app.md)
- [taffish emitter](builtin-taffish.md)
- [container emitter](builtin-container.md)
