# taffish-mcp

`taffish-mcp` 是面向 AI 客户端的 MCP stdio server。它是现有 TAFFISH 实现之上的适配层，不是新的业务层。它的职责是暴露保守的、结构化的 tools、resources 和 prompts，让 AI 客户端可以理解 TAFFISH 状态，而不是只能从非结构化终端输出中猜。

## 系统位置

`taffish-mcp` 在 `taffish-core`、`taffish-cli`、`taf-core` 和 `taf-cli` 之后加载。这是有意设计：

1. `taffish-core` 负责语言编译。
2. `taf-core` 负责项目、Hub、config、history 和 install 逻辑。
3. `taffish-mcp` 把已有安全能力转换成 MCP JSON-RPC tools/resources/prompts。

它不应该变成项目系统、Hub 系统或编译器的第二套实现。如果某条规则属于 TAFFISH 本身，它应该放在 `taffish-core` 或 `taf-core`；MCP 只负责调用它并整理结果。

## 安全边界

MCP server 暴露的是偏只读和偏编译的能力。它有意不暴露：

1. `taf run`。
2. `taf publish`。
3. 容器镜像 build/push。
4. 任意 shell 执行。

编译类工具可以返回生成的 shell code，但不会执行它。app invocation compile 会校验参数并返回 shell code，但不会运行 taf-app，也不会拉取容器镜像。

Smoke 和 trust 元数据只作为数据暴露给 AI 检查。MCP 不会运行 smoke command，
也不会拉取镜像或启动容器来验证它们。

Package 维护工具以 planner 为核心。`taffish_check_outdated`、
`taffish_plan_install_all`、`taffish_plan_upgrade` 和 `taffish_plan_prune`
调用的仍然是 CLI 使用的 `taf-core` 维护 API，但在 MCP 中始终保持 dry-run
语义。它们可以读取本地 index 和 install metadata，但不能安装、升级、清理、
删除文件或运行容器。

对于暴露 `containerBackend` 的 compile 工具，有效 backend 的优先级是：

1. 显式 MCP tool 参数 `containerBackend`。
2. MCP server 进程环境中的 `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`。
3. 自动后端选择。

这只会影响通用 `<container:...>` tag 的生成 shell。MCP 仍然不会执行 shell 或启动容器。

MCP compile 工具也会继承 MCP server 进程中的本机 runtime arg 环境变量：

1. `TAFFISH_DOCKER_RUN_ARGS`
2. `TAFFISH_PODMAN_RUN_ARGS`
3. `TAFFISH_APPTAINER_RUN_ARGS`

这些变量只影响生成的 shell。MCP 不会执行 shell。

## 主要文件

| 文件 | 职责 |
| --- | --- |
| `package.lisp` | 包导出。 |
| `protocol.lisp` | MCP JSON-RPC framing、response helper、JSON 转换、version/help 文本。 |
| `compiler.lisp` | 基于 `taffish-core` 的 source/file 验证、编译和摘要。 |
| `app.lisp` | 已安装 taf-app 的解析、检查、用法摘要和安全 app invocation compile。 |
| `project.lisp` | 当前项目检查、用法摘要、check、compile 和安全 build helper。 |
| `tools.lisp` | MCP tool 注册和分发。 |
| `resources.lisp` | MCP resources，包括帮助、tool 模型、当前项目文件和维护者指引。 |
| `prompts.lisp` | 引导 AI 客户端走安全流程的 MCP prompts。 |
| `server.lisp` | stdio JSON-RPC server loop。 |
| `main.lisp` | `taffish-mcp` CLI 入口。 |

## Tool 设计

Tool 名字统一使用稳定的 `taffish_` 前缀。名字应该足够短，方便 AI 理解；也要足够明确，能看出所属领域：

1. `taffish_compile_source` 等 source/file tool 是编译器 helper。
2. `taffish_inspect_app`、`taffish_summarize_app_usage`、`taffish_compile_app_invocation` 是 taf-app helper。检查/摘要结果应在可用时暴露 smoke/trust 元数据。
3. `taffish_check_project`、`taffish_inspect_project`、`taffish_compile_project` 是当前项目 helper。项目检查/摘要结果应在可用时暴露 smoke/trust 元数据。
4. Hub/system helper 提供安全查询和 dry-run 操作。
5. `taffish_check_outdated`、`taffish_plan_install_all`、
   `taffish_plan_upgrade` 和 `taffish_plan_prune` 是 package 维护 planner；
   MCP 应先用它们生成计划，再建议用户执行有副作用的 CLI 命令。

错误结果应尽量使用结构化输出：

```json
{
  "ok": false,
  "error": {
    "kind": "business-error",
    "message": "human-readable error"
  }
}
```

这很重要，因为 MCP 客户端不应该通过解析英文文本来判断发生了什么。

## Resources 和 Prompts

Resources 是 AI 在选择工具前可以读取的参考材料，应该保持简洁、可操作。Prompts 应编码推荐工作流，而不是长篇说明文。

好的 resource 应说明：

1. 有哪些工具。
2. 哪个工具适合哪个安全任务。
3. 当前项目包含什么。
4. 哪些事不应该通过 MCP 做。

不好的 resource 会重复全部源码，或者引导 AI 绕开 TAFFISH 命令。

## 修改指南

修改 `taffish-mcp` 时，应检查：

1. 新 tool 是否和已有 tool 重复。
2. 是否暴露了执行、发布、镜像构建或任意 shell 行为。
3. 是否调用已有 `taffish-core` / `taf-core` 逻辑，而不是重新实现。
4. 返回 JSON 是否保持数组为数组、对象为对象。
5. 错误结果是否有足够结构，方便 AI 客户端处理。
6. resources/prompts 是否说明了推荐安全流程，但不过度占用上下文。
7. 如果它计划一个有副作用的 CLI 操作，MCP 版本是否仍然只做 dry-run。
