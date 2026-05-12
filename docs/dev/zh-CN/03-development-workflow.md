# 开发流程与维护约定

本页记录维护 TAFFISH 源码时的基本流程。它不是用户安装教程，也不是测试报告。

## 开发前先定位层级

改代码前先判断需求属于哪一层：

| 需求类型 | 优先位置 |
| --- | --- |
| TAF 语法、参数绑定、编译输出 | `taffish-core` |
| `taffish` 命令行参数和输出格式 | `taffish-cli` |
| 项目创建、检查、构建、运行、发布 | `taf-core/project/` |
| hub index、搜索、安装、卸载、定位 | `taf-core/hub/` |
| TAFFISH home、配置、历史、诊断 | `taf-core/system/` |
| `taf` 子命令分发和 CLI 文本 | `taf-cli` |
| 跨模块基础能力 | `vendor/han` |

如果一个改动看起来要同时碰很多层，先确认是不是职责切分不清。TAFFISH 最重要的维护原则之一是：语言核心保持干净，上层生态逻辑放在 `taf-core`。

## 推荐阅读路径

修 `taffish-core` 时，建议按顺序读：

```text
package.lisp
model.lisp
lexer.lisp
parser.lisp
input.lisp
binder.lisp
emitter/model.lisp
emitter/registry.lisp
emitter/builtins/*.lisp
compiler.lisp
main.lisp
```

修 `taf-core` 时，建议先看：

```text
package.lisp
project/common.lisp
system/home.lisp
system/config.lisp
```

再进入具体子系统，例如 `project/check.lisp` 或 `hub/info.lisp`。

## 修改后的自查问题

每次修改后至少自问：

1. 这个改动是否改变了公开 API？
2. 是否改变了 `.taf` 到 shell 的输出契约？
3. 是否改变了 `taffish.toml`、hub index、config 的格式或默认值？
4. 是否需要同步更新 README、completion、install 脚本或文档？
5. 是否会影响 GitHub 与 Gitee 镜像场景？

## 测试说明

本手册记录测试入口，但不要求每次阅读文档都运行测试。常见开发检查包括：

```sh
sbcl --load load-taffish.dev.lisp
```

以及项目已有测试入口。具体测试命令以后应在独立测试文档中固化。

## 文档同步

新增文件或改变模块职责时，请同步更新：

1. [ASDF 系统与模块地图](01-asdf-system-map.md)
2. 对应模块 README
3. 相关标准文档

如果只是内部实现优化，可以只在对应模块的“实现要点”或“修改指南”里补充。

## 文档公开状态

`docs/` 是公开源码仓库的一部分。请把它视为需要维护的契约表面：避免私人笔记、过期的临时判断，以及未公开的研究或合作细节。行为发生变化时，应在同一个变更中同步更新相关开发者文档、规范文档或架构文档。

