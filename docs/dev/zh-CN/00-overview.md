# 总体架构

TAFFISH 是一个面向生物信息学工具和流程的可移植应用系统。它的底层核心不是“包装几个命令”，而是定义了一套 TAF 描述语言，并把这种语言稳定编译为 POSIX shell 脚本，再通过 `taf` 命令围绕项目、hub、安装、运行、诊断形成完整工作流。

## 命令与协议入口

当前仓库中有两个主要命令入口，以及一个面向 AI 的协议入口：

| 入口 | 所属系统 | 面向对象 | 核心职责 |
| --- | --- | --- | --- |
| `taffish` | `taffish-cli` | TAF 编译器用户和底层调试者 | 读取 `.taf`，执行词法、语法、绑定、发射，输出 shell。 |
| `taf` | `taf-cli` | 普通用户、taf-app 作者、hub 使用者 | 创建项目、检查项目、构建、运行、发布、安装、搜索和诊断。 |
| `taffish-mcp` | `taffish.mcp` | MCP 兼容 AI 客户端 | 暴露保守的结构化 tools/resources/prompts，用于 inspection、validation、安全编译和项目/app 理解。 |

可以把 `taffish` 理解为语言编译器，把 `taf` 理解为围绕这个语言和生态建立的应用管理工具，把 `taffish-mcp` 理解为覆盖二者安全子集的 AI 结构化接口。

## 核心链路

TAF 源码从文本到 shell 的链路如下：

```text
.taf source
  -> lex-taf
  -> parse-taf
  -> normalize-input-args / normalize-input-context
  -> bind-taf
  -> compile-taf-result
  -> emitter
  -> shell script
```

这条链路由 `taffish-core` 负责。每一步都应该尽量保持单向、显式和可调试：

| 阶段 | 主要文件 | 输入 | 输出 | 关键责任 |
| --- | --- | --- | --- | --- |
| 模型 | `model.lisp` | 无 | 条件、token、line、program、result 等结构 | 定义跨阶段共享的数据结构。 |
| 词法 | `lexer.lisp` | 文本流或字符串 | `taf-line` 列表 | 把 TAF 文本切成带位置的逻辑行。 |
| 语法 | `parser.lisp` | `taf-line` 列表 | `taf-program` | 识别 ARGS、RUN、子标签和参数规格。 |
| 输入 | `input.lisp` | 外部参数和上下文 | 规范化输入结构 | 把 CLI、容器、路径、CPU 等环境信息统一起来。 |
| 绑定 | `binder.lisp` | program、args、context | `taf-result` | 把参数和内置变量绑定到可编译结果。 |
| 发射 | `emitter/*` 与 `emitter/builtins/*` | 编译块 | shell 片段 | 按标签把 TAF 块转换为 shell。 |
| 编译 | `compiler.lisp` | program 或 result | shell 字符串 | 组织 prelude、block、finalize。 |

## 上层工作流

`taf-core` 建立在 `taffish-core` 之上，负责把语言编译器变成一个可使用的项目系统：

```text
taf new
  -> 生成 taf-app 项目骨架

taf check
  -> 读取 taffish.toml
  -> 检查项目元数据、入口、依赖和 release

taf compile / build / run
  -> 调用 taffish-core
  -> 生成目标脚本或可分发产物

taf hub/info/search/install/outdated/upgrade/prune/list/which
  -> 读取本地 hub index
  -> 定位、安装、维护和清理包、命令、artifact、版本和下载源

taf system/config/history/doctor
  -> 管理系统目录、配置、历史、诊断信息

taffish-mcp
  -> 暴露安全的 MCP tools/resources/prompts
  -> 检查已安装 app 和当前项目
  -> 在不运行工作流的前提下验证或编译源码、项目、app invocation
```

## 目录总览

| 路径 | 作用 |
| --- | --- |
| `taffish.asd` | TAFFISH 主 ASDF 系统定义，决定加载顺序和模块边界。 |
| `load-taffish.dev.lisp` | 开发加载入口。 |
| `vendor/han/` | 内置基础库，提供跨平台与通用解析能力。 |
| `taffish-core/` | TAF 语言核心。 |
| `taffish-cli/` | `taffish` 命令入口。 |
| `taf-core/` | `taf` 的项目、hub、系统能力。 |
| `taf-cli/` | `taf` 命令入口。 |
| `taffish-mcp/` | 面向 AI 客户端的 MCP stdio server。 |
| `install/` | 面向二进制分发的安装脚本。 |
| `completion/` | shell 补全。 |
| `vim-highlight/` | TAF 语法高亮。 |

## 当前设计的核心判断

TAFFISH 的核心价值来自三件事的组合：

1. TAF 语言把工具、流程、参数和容器运行方式描述成一个可编译对象。
2. 编译结果是 shell，因此系统边界清楚，运行时依赖轻，可移植性强。
3. `taf` 和 hub 机制把单个 TAF 程序提升为可发现、可安装、可复现的应用生态。

维护代码时要保护这三个性质。任何改动如果让 `.taf` 变得难以静态检查、让输出 shell 变得不透明，或者让 hub 中的 app 难以长期维护，都应该谨慎评估。

当前稳定编译主路径是 `parse-taf -> bind-taf -> compile-taf-result`。`compile-taf-program` 是内部保留函数，不导出、未实现，调用方不应把它当成公开入口。
