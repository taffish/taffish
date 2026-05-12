# taf-cli

`taf-cli` 是 `taf` 命令的实现层。它把 `taf-core` 的项目、hub、系统能力暴露为用户命令。

## 作用

`taf` 是普通用户和 taf-app 作者最常接触的入口。它应该提供稳定、清楚、可脚本化的命令体验。

`taf-cli` 主要负责：

1. 解析子命令。
2. 组织 CLI help 和错误输出。
3. 调用 `taf-core` 对应 API。
4. 把结果展示给用户。

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

## 修改指南

修改 `taf-cli` 时应检查：

1. completion 是否需要更新。
2. README 中的命令示例是否需要更新。
3. 错误码和输出是否仍适合脚本调用。
4. 是否把业务逻辑错误地写进 CLI 层。

长期看，`taf-cli` 的命令设计会直接影响 TAFFISH 的用户体验。它应保持稳定、短句清楚、错误可定位。
