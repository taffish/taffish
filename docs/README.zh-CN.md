# TAFFISH 文档

这个目录记录 TAFFISH 的实现、规范和生态设计知识。它面向维护者、贡献者、需要理解底层契约的 taf-app 作者，以及希望理解本地 CLI、Hub index、容器、镜像源和 MCP 接口如何协同工作的用户。

普通用户可以先阅读根目录的 [README-CN](../README-CN.md)。这里的文档会比安装和基础命令使用更深入。

## 文档范围

这里优先记录四类内容：

1. 代码架构：ASDF 系统、包、模块、文件之间的职责边界。
2. 规范草案：TAF 语言、项目格式、Hub index、安装元数据、配置、运行环境等系统契约。
3. 系统架构：GitHub/Gitee 组织、Hub、index、发布、镜像和生态运行方式。
4. 开发流程：修改某个模块时应该读哪里、保持哪些不变量、如何避免破坏上下游。

这个目录不试图替代官网或 Hub 用户指南。论文叙事、完整教程和应用级示例可以在稳定后放入专门仓库或官网文档。

## 入口

- [开发者手册](dev/README.zh-CN.md)
- [TAFFISH 规范草案](standards/README.zh-CN.md)
- [TAFFISH 系统架构](architecture/README.zh-CN.md)
- [Release Notes](releases/v0.8.1.zh-CN.md)

英文入口：

- [Developer Manual](dev/README.en.md)
- [TAFFISH Specification Draft](standards/README.en.md)
- [TAFFISH System Architecture](architecture/README.en.md)
- [English Release Notes](releases/v0.8.1.md)

## 写作原则

每一篇开发文档都应该先回答“这部分代码为什么存在”，再回答“它导出了什么 API”。只列函数名通常是不够的，因为 TAFFISH 的关键复杂度来自模块之间的契约，而不是单个函数本身。

规范文档则应先回答“TAFFISH 对外或对生态承诺什么”，再说明当前参考实现如何满足该承诺。规范可以引用实现，但不应被具体文件结构绑死。

系统架构文档应回答“TAFFISH 生态由哪些仓库、组织、索引、镜像和发布链路组成”。它可以引用规范和开发文档，但重点不是代码实现，也不是单个 schema 的字段定义。

推荐顺序是：

1. 作用。
2. 系统位置。
3. 上下游交互。
4. 核心数据结构或不变量。
5. 公开 API。
6. 实现要点。
7. 修改指南。

## 状态说明

这是一套活文档。它应该随着源码一起演进，而不是等项目完成后再补写。TAFFISH 的核心代码已经形成了比较清晰的分层；当前文档包含开发者手册、规范草案和系统架构的中英文版本。后续可以继续补充更细的专题、测试文档、发布 runbook 和面向普通用户的公开文档。
