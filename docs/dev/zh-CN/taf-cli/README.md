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

`main.lisp` 在 dispatch 前通过 `taffish.i18n` 建立人类语言上下文。`i18n.lisp` 拥有完整的
内置中英文 help 和常见顶层诊断。两种语言中的 command/option token 必须一致；底层业务
错误仍可能使用英文回退。

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
| `i18n.lisp` | 管理本地化 help 和常见人类 CLI 诊断。 |
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
| `taf outdated` | 只读比较本地 install metadata 和本地 index。 |
| `taf upgrade` | 输出 dry-run upgrade 计划；必须显式 `--yes` 才会安装新 indexed 版本。 |
| `taf prune` | 输出 dry-run cleanup 计划；必须显式 `--yes` 才会删除本地旧 app 版本。 |

这些命令要和对应 `taf-core` API 保持 `--user` / `--system`、`--json`、
kind filter 和 target 解析一致。它们不能删除共享容器镜像缓存。

默认文本输出以“变化”为中心。当所有 item 都已经是 current 或被 skipped 时，
命令应输出简短的 `no changes`，而不是逐条列出所有未变化 app。JSON 输出仍然是
完整机器可读 plan，会保留 current/skipped items，供自动化使用。

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
