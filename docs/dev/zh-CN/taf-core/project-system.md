# taf-core 项目系统

项目系统位于 `taf-core/project/`，负责 taf-app 从创建到检查、编译、构建、运行、发布的本地工作流。

## 作用

项目系统把单个 `.taf` 文件放进一个可维护的应用项目中。它通过 `taffish.toml` 描述项目元数据，再调用 `taffish-core` 完成编译。

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `common.lisp` | 项目通用常量、路径、helper。 |
| `new.lisp` | 创建 taf-app 项目骨架。 |
| `check.lisp` | 读取并验证 `taffish.toml` 和入口文件。 |
| `compile.lisp` | 编译项目 TAF。 |
| `build.lisp` | 构建可分发产物。 |
| `run.lisp` | 在项目上下文中运行。 |
| `publish.lisp` | 发布相关逻辑。 |

## taffish.toml 的角色

`taffish.toml` 是 taf-app 项目的核心元数据文件。`project/check.lisp` 会读取它并检查：

1. package 名称。
2. kind，例如 tool 或 flow。
3. release 是否为正整数。
4. main 是否指向 `.taf` 入口。
5. 依赖字段是否合法。

当前实现包含一个小型 TOML 解析器，重点支持 TAFFISH 项目需要的子集。维护时不要假设它是完整 TOML 实现。

## 与 taffish-core 的关系

项目系统不应该自己实现 TAF 编译。它应当：

1. 读取项目元数据。
2. 定位入口 `.taf`。
3. 准备必要上下文。
4. 调用 `taffish-core` 编译。
5. 把结果放到项目或目标目录中。

如果项目系统开始直接解析 TAF 语法，说明职责越界。

## 修改指南

修改项目系统时应同步检查：

1. 新项目骨架是否仍能通过 `project-check`。
2. `taffish.toml` 的字段变化是否影响已有 taf-app。
3. build 或 publish 产物是否仍能被 hub index 描述。
4. README、completion 和 CLI help 是否需要更新。
