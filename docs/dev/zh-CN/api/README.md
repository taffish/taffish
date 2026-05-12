# 公开 API

这里记录 TAFFISH 中“可以被其他模块、未来协作者或维护脚本相对稳定调用”的 API。它不是正式对外 SDK 承诺，也不意味着这里列出的每个接口都已经适合任意第三方稳定调用。

## 稳定性标签

| 标签 | 含义 |
| --- | --- |
| 稳定 | 当前推荐调用，短期内应保持兼容。 |
| 半稳定 | 已导出或被多处使用，但可能随架构演进调整。 |
| 保留 | 已导出或占位，但当前不建议调用。 |
| 内部 | `%` 开头或未导出函数，不作为 API 承诺。 |

## 重要规则

1. `%` 开头函数默认是内部实现，不应写进上层新代码作为依赖。
2. package 导出不等于完全稳定。部分导出是为了调试、结构访问或未来扩展。
3. 有文件系统、git、网络、安装、删除副作用的 API 必须单独写安全说明。
4. API 文档优先说明输入、输出、错误和副作用，不重复实现细节。

## 文档入口

- [taffish-core API](taffish-core-api.md)
- [Emitter API](emitter-api.md)
- [taf-core API](taf-core-api.md)
- [han API](han-api.md)

## API 层级

TAFFISH 当前 API 可以分为四层：

| 层级 | 推荐调用方 | 典型入口 |
| --- | --- | --- |
| `han` | TAFFISH 内部基础库调用者 | `han.args:bind-args`、`han.json:read-json-file`、`han.path:join-path` |
| `taffish-core` | TAF 编译器调用者 | `taffish.core:taffish-to-shell` |
| emitter | TAFFISH 内置或未来扩展标签作者 | `taffish.core:defemitter`、`taffish.core:emit-block` |
| `taf-core` | `taf-cli`、管理工具、自动化脚本 | `taf.core:project-build`、`taf.core:hub-install`、`taf.core:system-doctor` |

普通用户命令行体验由 `taf-cli` 和 `taffish-cli` 提供，CLI 层 API 暂不作为重点。
