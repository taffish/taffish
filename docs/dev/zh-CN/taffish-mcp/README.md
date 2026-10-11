# taffish-mcp

`taffish-mcp` 是面向 AI 客户端的 MCP stdio server。它是现有 TAFFISH 实现之上的适配层，不是新的业务层。它的职责是暴露保守的、结构化的 tools、resources 和 prompts，让 AI 客户端可以理解 TAFFISH 状态，而不是只能从非结构化终端输出中猜。

## 系统位置

`taffish-mcp` 在 `taffish-core`、`taffish-cli`、`taf-core` 和 `taf-cli` 之后加载。这是有意设计：

1. `taffish-core` 负责语言编译。
2. `taf-core` 负责项目、Hub、config、history 和 install 逻辑。
3. `taffish-mcp` 把已有安全能力转换成 MCP JSON-RPC tools/resources/prompts。

它不应该变成项目系统、Hub 系统或编译器的第二套实现。如果某条规则属于 TAFFISH 本身，它应该放在 `taffish-core` 或 `taf-core`；MCP 只负责调用它并整理结果。

## 人类 CLI Help 与机器语言边界

`taffish-mcp -h`、`taffish-mcp --help` 和 `taffish-mcp help` 属于人类 CLI 表面，
与 `taf`、`taffish` 一样遵循 `taf config language` 和 `TAFFISH_LANGUAGE`，并内置
英文、中文 help。

不带 help 参数启动 `taffish-mcp` 时会直接进入 stdio server，不建立人类语言上下文。
MCP tool/resource/prompt 名、description、schema、结构化结果和面向 AI 的 help 始终保持
稳定英文机器接口。

## 进程错误与中断

server 已处理的请求级失败继续返回 JSON-RPC error 或 tool error result，不会因此自动
终止 session。逃逸出 server 的致命启动或传输错误使用 `[TAFFISH-MCP-ERROR]` 前缀
写入 stderr，并以状态码 1 退出。报告无法写出时仍以失败退出，不向 stdout 发送备用文本。

外部中断与请求错误不同。SBCL 的 SIGINT 使用简短 stderr 诊断并退出 1；LispWorks
保留原生的 `<executable> : Interrupted - quitting` 固定 stdout 提示并退出 1，这是正常
protocol-only stdout 的已知例外。全局信号处理器和 SIGTERM 行为不变。边界范围及限制见
[han.host](../han/host.md)。

## 安全边界

MCP server 包含偏只读和偏编译的能力，但不是全部只读。既有 `taffish_update_index`、
`taffish_create_project`、`taffish_build_project` 会写本地文件；`taffish_install_app`
和 `taffish_uninstall_app` 默认 dry-run，但可按请求执行变更。这些既有能力不变。
它有意不暴露：

1. `taf run`。
2. `taf publish`。
3. 容器镜像 build/push。
4. 任意 shell 执行。

编译类工具可以返回生成的 shell code，但不会执行它。app invocation compile 会校验参数并返回 shell code，但不会运行 taf-app，也不会拉取容器镜像。

Smoke 和 trust 元数据只作为数据暴露给 AI 检查。MCP 不会运行 smoke command，
也不会拉取镜像或启动容器来验证它们。

`taffish_check_environment` 是 `taf.core:system-doctor` 的只读投影，返回 home、
config、index、PATH、completion、Vim/Neovim、Apptainer SIF cache 和有时间上限
backend probe 的 additive diagnostic schema。它的 input schema 明确不包含
init、fix、force 或 repair 操作，也不会修改配置或权限、启动服务、拉取镜像或
运行容器。

可选 `check` 为 `environment`（默认）、`index` 或 `hub`。
`targets: ["APP", "taf-APP-v1.4.0-r1"]` 仅与 `check: "hub"` 搭配使用。
index/hub 检查完全离线，不探测后端。即使 `exit_code` 为 1，返回诊断结果仍表示
工具调用成功；应读取 `diagnostic_status`、每项 `inspection.state` 和问题代码，
不能只检查 `isError`。参数无效仍返回工具错误。不新增工具名或自动修复能力。
旧 manifest 缺失只是未验证证据，不等于损坏；不安全链接/未知格式保持 unknown。
人类语言配置不会翻译机器字段。
`hub_command` 是无版本命令入口的独立警告，不代表对应 `hub_installation`
的产物损坏。应分别读取两类检查，不把缺少证据解释成正常或损坏。

默认人类 Hub 摘要不限制 MCP 的证据：结构化检查和 issues 完整保留，机器字段与类型稳定。
共享只读扫描使用批量探测加速，不引入持久验证缓存或减少摘要校验；MCP 不输出人类 TTY/
日志进度。CLI/core 的 `install --repair` 刻意不暴露给 MCP：不新增 repair tool、参数或
执行入口，既有 install tool 也不是 repair 入口；这不移除既有 MCP 写操作。

Package 维护工具以 planner 为核心。`taffish_check_outdated`、
`taffish_plan_install_all`、`taffish_plan_upgrade` 和 `taffish_plan_prune`
调用的仍然是 CLI 使用的 `taf-core` 维护 API，但在 MCP 中始终保持 dry-run
语义。它们可以读取本地 index 和 install metadata，但不能安装、升级、清理、
删除文件或运行容器。

这些 planner 以 index.latest 为在线目标，使用统一版本比较器判断本地优先级，
包括混合数字后缀；不会自动降级。prune 计划要求同源 latest 已安装且验证有效，
缺少目标或受到保护的版本不会进入删除列表。工具名称、参数 schema 与 dry-run
安全边界保持不变。

增量 `validation`/`validations` 字段将文件证据与版本状态分开。
旧的未验证安装不阻断普通计划；选中安装为 invalid/unknown 时汇总明确的处理建议，
在写入型计划应用前阻断。prune 保护包含未验证证据的整个包。

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
| `i18n.lisp` | 只为人类 CLI 入口提供内置英/中文 help。 |
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
6. `taffish_check_environment` 复用 core doctor result，只暴露只读结构化诊断，
   不能获得 init/repair 输入。

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
7. 维护 planner 是否仍为 dry-run，既有写工具是否保留显式控制，repair 是否仍未暴露。

## 人类命令状态提示

CLI 阶段提示不进入 MCP stdout 或 stderr。工具保留已有静默 core 调用及结果 schema，
不新增进度工具或通知。人类显示合同见[命令状态与进度](../taf-core/command-progress.md)。

CLI 的 `taf install --all-installed --repair` 单独预览本地全部已安装版本的修复；
它不是 MCP 工具或参数，不扩张 AI 写权限。MCP 维护计划继续使用 index.latest 语义。
doctor 保持只读，人类摘要的调整不裁剪其完整结构化诊断。
