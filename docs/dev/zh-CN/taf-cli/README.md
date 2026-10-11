# taf-cli

`taf-cli` 是 `taf` 命令的实现层。它把 `taf-core` 的项目、hub、系统能力暴露为用户命令。

## 作用

`taf` 是普通用户和 taf-app 作者最常接触的入口。它应该提供稳定、清楚、可脚本化的命令体验。

`taf-cli` 主要负责：

1. 解析子命令。
2. 组织 CLI help 和错误输出。
3. 调用 `taf-core` 对应 API。
4. 把结果展示给用户。

help 是公开 CLI 表面的一部分。`taf --help` 应保持简洁，而 `taf help <command>`
和 `taf <command> --help` 应把用户带到同一份 command-specific help 文本。

顶层帮助依次提供项目、Hub、系统命令，再给出入门示例、语言设置和官网/Hub/支持邮箱。
描述中应区分刷新索引与升级应用，并明确 doctor 默认只读。联系信息只放在顶层帮助，
不重复加入每个子命令或机器输出。`--version` 保持单行命令名和版本号。

`main.lisp` 在 dispatch 前通过 `taffish.i18n` 为本次调用建立一次人类语言上下文。
`i18n.lisp` 拥有完整的内置中英文 help 和 parser 诊断；project、Hub、package、config、
doctor 与 history 消息由 `taf-core` 对应的人类 renderer 管理。所有语言中的 command/option
token 与机器接口必须一致。

## 错误处理

可执行入口在 TAFFISH runtime I/O 和语言初始化前建立内部错误边界。逃逸出命令处理器的
错误使用 `[TAF-ERROR]` 前缀写入 stderr，并以状态码 1 退出。报告错误本身再次失败时，
进程仍以失败退出，不向 stdout 写入备用错误信息。正常命令结果和既有非零退出语义不变。

这不会改变 `taf-core` 库函数的 condition 处理方式。实现相关的信号行为及限制见
[han.host](../han/host.md)。

## 系统位置

```text
user
  -> taf command
  -> taf-cli
  -> taf-core
  -> taffish-core
```

## 文件职责

| 文件 | 作用 |
| --- | --- |
| `package.lisp` | 定义 CLI 包。 |
| `i18n.lisp` | 管理本地化 help 和 parser 层人类诊断。 |
| `run.lisp` | 实现子命令分发和运行。 |
| `main.lisp` | 提供入口函数。 |

## 与 taf-core 的边界

`taf-cli` 可以处理命令行表现，但业务规则应放在 `taf-core`。

例如：

| 问题 | 应放位置 |
| --- | --- |
| 某个子命令叫什么 | `taf-cli` |
| 子命令 help 怎么显示 | `taf-cli` |
| `taffish.toml` 是否合法 | `taf-core/project/check.lisp` |
| hub index 如何解析 | `taf-core/hub/info.lisp` |
| config 默认值是什么 | `taf-core/system/config.lisp` |

## Hub 维护命令

package 维护命令面采用保守 CLI 模式：

| 命令 | 默认行为 |
| --- | --- |
| `taf install --all` | 为 `--kind`、`--tools` 或 `--flows` 选中的全部 indexed apps 输出 dry-run 计划。 |
| `taf install TARGET... --repair` | 显式修复已有身份；添加 `--dry-run` 才只预览、不执行。 |
| `taf install --all --repair` | 默认预览已安装的 index.latest 身份，`--yes` 才执行；保留 kind 和 scope 筛选。 |
| `taf install --all-installed --repair` | 默认预览本地全部已安装版本（含历史版本），`--yes` 才执行；不新增版本或依赖。 |
| `taf outdated` | 只读比较本地 install metadata 和本地 index。 |
| `taf upgrade` | 输出 dry-run upgrade 计划；必须显式 `--yes` 才会安装新 indexed 版本。 |
| `taf prune` | 输出 dry-run cleanup 计划；必须显式 `--yes` 才会删除本地旧 app 版本。 |

这些命令要和对应 `taf-core` API 保持 `--user` / `--system`、`--json`、
kind filter 和 target 解析一致。它们不能删除共享容器镜像缓存。

默认文本输出以“变化”为中心。当所有 item 都已经是 current 或被 skipped 时，
命令应输出简短的 `no changes`，而不是逐条列出所有未变化 app。JSON 输出仍然是
完整机器可读 plan，会保留 current/skipped items，供自动化使用。
即使版本没有变化，unverified/invalid/unknown 的安装诊断也会保留在文本中，按问题
类型/状态和处理策略汇总，每组至多三个例子，不重复 skip 行。doctor 的 `--verbose`
及 JSON 保留完整证据。

批量修复有两种选择方式：`--all --repair` 只检查已安装的 `index.latest`，
未安装的最新版会跳过，不会补装。`--all-installed --repair` 从本地枚举全部已安装版本，
包括历史版本；不升级、不安装缺失版本或依赖、不清理。两者都默认预览，确认后加
`--yes` 才执行，也都支持 `--json`、作用域和类型筛选。两种选择器不能并用，也不能与
显式目标并用；`--all-installed` 必须配合 `--repair`。显式版本目标使用 `--dry-run`
预览，去掉该参数即执行。已通过验证的目标跳过。

缺失或不可读的安装记录、已不在索引中的版本会保留为受阻目标，不会静默漏掉。
无法确定类型的目标不能被类型筛选静默排除，私有安装不从公共索引覆盖。
修复不能与 `--force`、`--from`、`--prune-old` 组合。


## Doctor 路由

`taf doctor` 保持轻量环境检查。`taf doctor index` 检查缓存索引，
`taf doctor hub [APP|COMMAND...]` 还检查本地安装证据。两种专项模式接受
user/system、json/verbose，但拒绝 init/shell。core 返回的 `:exit-code` 直接
成为 CLI 退出码，不向 JSON stdout 添加错误文本。error/unknown 退出 1，只有 warning
时退出 0；默认 doctor 的旧退出行为不变。详见[诊断与恢复](../taf-core/system-history-doctor.md)。

doctor 与维护命令的人类进度只写 stderr：TTY 原地显示阶段/计数，日志计数限频，
JSON/MCP 无进度文字。字段对齐采用共享的保守 Unicode 宽度，长或复杂文本分行。
这些展示变化不改变机器字段、安全分类或退出码。

## 语言管理

`taf config language` 与 `taf config language --show` 提供相同的只读状态和发现视图。
提供 `en`、`zh`、`auto` 或已发现外部 locale 时，通过
`taf.core:system-config-language` 窄更新配置。CLI parser 必须拒绝把语言值与 `--show`、
profile flag 或 `--force` 混用。这个人类 CLI 表面不会派生 MCP 修改工具。

缺少已保存偏好时，configured language 显示为 `auto`：人类 CLI 输出跟随可识别的主机
locale，并最终回退到英文。显式 `en` 或 `zh` 保持确定性，不会被主机 locale 变量覆盖。

## 修改指南

修改 `taf-cli` 时应检查：

1. completion 是否需要更新。
2. README 中的命令示例是否需要更新。
3. 错误码和输出是否仍适合脚本调用。
4. 是否把业务逻辑错误地写进 CLI 层。
5. 中英文 help 是否保留相同 command/option 契约。
6. JSON 和 MCP 投影是否仍是稳定英文机器接口。

长期看，`taf-cli` 的命令设计会直接影响 TAFFISH 的用户体验。它应保持稳定、短句清楚、错误可定位。

## 操作状态提示

慢操作会在 stderr 提示当前目标与阶段。TTY 更新、日志限频、目标计数的含义、
静默/JSON 行为及限制见[命令状态与进度](../taf-core/command-progress.md)。提示不改变校验、写操作、重试或退出码规则。
