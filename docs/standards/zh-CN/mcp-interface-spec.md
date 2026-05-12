# TAFFISH MCP 接口规范

本页定义 `taffish-mcp` stdio MCP server 的稳定契约。它是面向 AI 的消费侧集成接口，不是 `taf` 或 `taffish` 的替代品。

## 范围

规范性：`taffish-mcp` 通过 MCP tools、resources 和 prompts 暴露 TAFFISH 的安全结构化能力。

该接口可以暴露：

1. 版本和帮助元数据。
2. source/file 的验证、摘要和编译到 shell。
3. 已安装 taf-app 的查找、检查、用法摘要、trust/smoke 元数据暴露和 invocation compile。
4. 当前项目的 check、inspection、用法摘要、trust/smoke 元数据暴露、compile 和安全 build planning。
5. Hub search/info/list/which/update 操作。
6. config、environment 和 history 查询操作。
7. dry-run install/uninstall helper。

该接口必须不暴露：

1. 任意 shell 执行。
2. `taf run`。
3. `taf publish`。
4. 容器镜像 build、push 或 registry mutation。
5. 任何没有显式 force 类参数却静默覆盖用户文件的操作。

## 传输

规范性：主要传输方式是 MCP 客户端预期的 stdio JSON-RPC。

`stdout` 保留给 MCP 协议消息。诊断日志应写入 `stderr`，避免破坏 JSON-RPC framing。

## Tool 命名

规范性：tool 名称使用 `taffish_` 前缀。

名称应该清楚且稳定。如果 tool 被重命名，旧名称应保留为 alias 直到文档化的移除点，或者这次变化应被视为 MCP 接口破坏性变更。

推荐领域：

| 领域 | 示例 |
| --- | --- |
| compiler | `taffish_validate_source`、`taffish_compile_file` |
| taf-app | `taffish_inspect_app`、`taffish_compile_app_invocation` |
| project | `taffish_check_project`、`taffish_compile_project` |
| Hub | `taffish_search_apps`、`taffish_install_app` |
| system | `taffish_check_environment`、`taffish_get_config` |

## 结构化结果

规范性：返回结构化数据的成功操作应包含足够字段，让 AI 客户端不需要解析自然语言也能继续工作。

规范性：预期内业务失败应尽量使用以下形状：

```json
{
  "ok": false,
  "error": {
    "kind": "error-kind",
    "message": "human-readable message"
  }
}
```

`kind` 应足够稳定，方便客户端分支处理；`message` 用于人类解释和调试。

成功的 compile 操作应该包含 `ok: true`、必要时包含生成的 `shell`，以及 byte count 或 validation metadata 等摘要字段。

## 编译安全

规范性：source、file、project 和 app invocation compile tool 可以返回 shell code，但必须不执行它。

app invocation compile 应使用和正常 TAFFISH 编译相同的底层参数绑定逻辑校验参数。它是面向 AI 客户端的安全预览路径，不是运行时。

容器后端可用性可以被探测并放入 compiler context，但 MCP compile 操作不能拉取镜像或启动容器。

对于接收 `containerBackend` 的工具，有效强制 backend 的优先级是：

1. 显式 `containerBackend` tool 参数。
2. MCP server 进程环境中的 `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`。
3. 不强制 backend。

强制 backend 只作用于生成 shell 中的通用 `<container:...>` tag。显式 `<docker:...>`、`<podman:...>` 和 `<apptainer:...>` tag 仍保持显式含义。

## Smoke 和 Trust 元数据

规范性：app 和 project 的 inspection/summary tool 应在可用时暴露 smoke/trust
元数据。

对于容器化项目，`taf check` 会验证 smoke 元数据，并拒绝默认 TODO 占位。MCP
可以报告这个验证结果，但必须不执行 smoke command、不拉取镜像，也不启动容器来
验证 smoke。

对于 index 中的 app，trust 元数据可以包含 container digest、支持平台、smoke
状态和 source commit 等字段。这些字段是给 AI 推理和审计准备使用的数据，不是
MCP 自己生成的证明。

## Resources

Resources 给 AI 客户端提供参考材料，应保持简洁、稳定和可操作。

推荐 resources：

1. Tool overview。
2. Compiler usage model。
3. Hub/install usage model。
4. Project inspection model。
5. 存在 project root 时的当前项目文件。

Resources 不应复制整个代码库，也不应成为诱导不安全操作的隐藏 prompt。

## Prompts

Prompts 编码 AI 客户端的推荐工作流，应引导模型先安全检查，再决定动作。

示例：

1. 修改或构建项目前先 inspect project。
2. 编译 taf-app invocation 前先 resolve 并 inspect taf-app。
3. 展示生成 shell 前先 validate source。

Prompts 不应鼓励通过 MCP 执行、发布或修改镜像。

## 兼容性

MCP 接口兼容性独立于 TAFFISH CLI 兼容性。某个变化可能对 CLI 兼容，但如果改变了 tool 名称、必需参数、结果形状或 resource URI，就可能破坏 MCP。

修改 MCP 接口前应检查：

1. 旧 tool 名称是否保留。
2. 旧必需参数是否仍被接受。
3. 成功和失败结果是否仍能被结构化读取。
4. resources 和 prompts 是否仍然简洁，并符合安全边界。
