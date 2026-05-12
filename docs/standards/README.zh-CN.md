# TAFFISH 规范草案

这个目录记录 TAFFISH 的逻辑契约和规范草案。它与 `dev/` 的关系是：

| 目录 | 面向对象 | 回答的问题 |
| --- | --- | --- |
| `dev/` | TAFFISH 实现维护者 | 代码在哪里、模块如何交互、API 如何实现。 |
| `standards/` | TAFFISH 生态和兼容性维护者 | 语言、项目、hub、安装、配置和运行时应承诺什么。 |

当前规范入口：

- [中文规范草案](zh-CN/README.md)
- [合规性检查清单](zh-CN/conformance-checklist.md)
- [English specification draft](README.en.md)
- [English conformance checklist](en/conformance-checklist.md)

## 定位

这里不是外部公证标准，也不是类似 ANSI Common Lisp 的正式标准。当前阶段更适合称为：

```text
TAFFISH Specification Draft v0.1
```

也就是 TAFFISH 规范草案。它可以随着参考实现和 taffish-hub 迁移继续演进，但应该有明确版本、兼容性策略和迁移说明。

## 与开发文档的边界

规范文档可以引用当前 Common Lisp 参考实现，但不应依赖某个具体函数或文件路径才能成立。

例如：

1. `taffish.toml` 有哪些字段，是规范问题。
2. `project-check` 如何解析这些字段，是开发文档问题。
3. hub index schema 是规范问题。
4. `hub-info` 如何查询 index，是开发文档问题。
5. 容器后端选择规则是规范问题。
6. `container.lisp` 如何生成 shell，是开发文档问题。

这个分层能让 TAFFISH 以后自然走向多实现、一致性测试和生态治理，而不是被当前源码结构锁死。

## 下一步用途

这套规范草案的直接用途是服务 taffish-hub 迁移。迁移时应优先检查：

1. 生成的 index 是否符合 `taffish.index/v1`。
2. 每个 taf-app 项目是否符合 `taffish.toml` 和目录规范。
3. 安装结果是否能生成正确的 `install.json` 和 launcher。
4. 中国镜像配置是否只通过 source rewrite 改变分发来源，而不改变 canonical GitHub 身份。
