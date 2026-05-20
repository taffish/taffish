# taf-core

`taf-core` 是 `taf` 命令背后的业务核心。它把 `taffish-core` 的编译能力扩展为项目、构建、运行、hub、安装、配置和诊断工作流。

## 作用

`taffish-core` 解决“如何把 TAF 编译成 shell”，而 `taf-core` 解决“如何把 TAF 作为一个可分发、可安装、可运行、可维护的应用生态来使用”。

## 系统位置

```text
taffish-core
  -> taf-core
  -> taf-cli
```

`taf-core` 可以调用 `taffish-core`，但 `taffish-core` 不应该反向依赖 `taf-core`。

## 子系统

| 子系统 | 路径 | 作用 |
| --- | --- | --- |
| project | `project/` | taf-app 项目创建、检查、编译、构建、运行、发布。 |
| hub | `hub/` | index 更新、查询、搜索、安装、维护、卸载、定位。 |
| system | `system/` | home 目录、配置、历史、诊断。 |

## 公开 API

`taf-core/package.lisp` 导出的 API 覆盖三类能力：

| 类别 | 示例 |
| --- | --- |
| 项目能力 | `project-new`、`project-check`、`project-compile`、`project-build`、`project-run`、`project-publish` |
| hub 能力 | `hub-update`、`hub-info`、`hub-search`、`hub-install`、`hub-install-all`、`hub-outdated`、`hub-upgrade`、`hub-prune`、`hub-uninstall`、`hub-list`、`hub-which` |
| 系统能力 | `system-config`、`system-config-path`、`system-config-init`、`system-doctor`、`system-history`、`system-record-history-event` |

具体导出以 `taf-core/package.lisp` 为准。

## 设计边界

`taf-core` 是业务层，但仍然应该保持清楚边界：

1. 项目元数据检查放在 `project/check.lisp`。
2. hub index schema 和 package 解析放在 `hub/info.lisp` 等 hub 文件。
3. 配置默认值和来源合并放在 `system/config.lisp`。
4. 文件系统目录约定放在 `system/home.lisp`。
5. CLI 文案和子命令分发尽量放在 `taf-cli`，不要塞回 `taf-core`。

## 相关专题

- [项目系统](project-system.md)
- [project/common 与 package](project-common.md)
- [project/new](project-new.md)
- [project/check](project-check.md)
- [project/compile 与 project/run](project-compile-run.md)
- [project/build](project-build.md)
- [project/publish](project-publish.md)
- [Hub 系统](hub-system.md)
- [hub/update、info、search](hub-index-query.md)
- [hub/install、uninstall](hub-install-uninstall.md)
- [hub/outdated、install-all、upgrade、prune](hub-maintenance.md)
- [hub/list、which](hub-list-which.md)
- [系统层](system-layer.md)
- [system/home 与 config](system-home-config.md)
- [system/history 与 doctor](system-history-doctor.md)
