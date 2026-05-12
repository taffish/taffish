# TAFFISH 开发者手册

这份手册解释 TAFFISH 自身如何实现。它不是“如何写 taf-app”的教程，而是“如何维护 TAFFISH 这个系统”的开发者说明。

## 推荐阅读顺序

1. [总体架构](zh-CN/00-overview.md)
2. [ASDF 系统与模块地图](zh-CN/01-asdf-system-map.md)
3. [模块文档模板](zh-CN/02-module-doc-template.md)
4. [开发流程与维护约定](zh-CN/03-development-workflow.md)
5. [0.8.0 开源准备 Checklist](zh-CN/04-open-source-0.8.0-checklist.md)
6. [从源码构建](zh-CN/build-from-source.md)
7. [han 基础库](zh-CN/han/README.md)
8. [taffish-core](zh-CN/taffish-core/README.md)
9. [taf-core](zh-CN/taf-core/README.md)
10. [taffish-cli](zh-CN/taffish-cli/README.md)
11. [taf-cli](zh-CN/taf-cli/README.md)
12. [taffish-mcp](zh-CN/taffish-mcp/README.md)
13. [公开 API](zh-CN/api/README.md)

相邻文档：[TAFFISH 规范草案](../standards/README.zh-CN.md) 记录语言、项目、hub、安装、配置、运行时等逻辑契约。开发者手册可以引用规范，但不把规范作为代码实现章节的一部分。

英文对应入口：[TAFFISH Developer Manual](README.en.md)。

## 手册边界

本手册只覆盖当前仓库中的 TAFFISH 开发内容。TAFFISH 规范草案、生态层，例如 taffish-hub、GitHub/Gitee 镜像、taf-app 发布与持续集成、hub index 的长期治理，属于更高层的系统架构专题。这里会在必要处说明接口和边界，但不会把规范或 hub 生态文档混进源码开发手册。

## 当前代码分层

TAFFISH 当前可以理解为六层：

| 层级 | 目录或系统 | 主要责任 |
| --- | --- | --- |
| 基础库 | `vendor/han` | 平台差异、路径、JSON、参数规格与绑定等通用能力。 |
| TAF 语言核心 | `taffish-core` | 把 `.taf` 源码从文本编译成可运行 shell 脚本。 |
| TAF 命令行入口 | `taffish-cli` | 提供面向 TAF 编译器的 CLI 入口。 |
| 项目与 hub 工具 | `taf-core` | 支持 `taf` 命令的项目、hub、系统配置、历史和诊断功能。 |
| taf 命令入口 | `taf-cli` | 提供面向用户工作流的 `taf` CLI 入口。 |
| AI 协议层 | `taffish-mcp` | 为 MCP 兼容 AI 客户端暴露保守的 tools/resources/prompts，不增加新的业务逻辑。 |

## 维护规则

新增或修改模块时，请同步更新对应文档。最小更新要求是：说明职责是否改变、公开 API 是否改变、上下游契约是否改变。

如果只是修复内部实现 bug，可以在对应模块文档的“修改指南”或“常见风险”中补充一句原因。TAFFISH 的文档目标不是堆砌内容，而是把后来者最容易误解的地方提前说清楚。
