# TAFFISH 系统架构

这个目录记录 TAFFISH 在代码之外的系统形态：GitHub/Gitee 组织、仓库分层、hub、index、发布链路、镜像链路和用户运行路径。

它与 `dev/` 和 `standards/` 的关系是：

| 目录 | 关注点 | 典型问题 |
| --- | --- | --- |
| `dev/` | 当前代码实现 | `project-publish` 怎么调用 git/gh？ |
| `standards/` | 逻辑契约 | `taffish.index/v1` 必须有哪些字段？ |
| `architecture/` | 生态拓扑和运行链路 | GitHub 组织里应该有哪些仓库？用户从哪里安装 app？ |

当前架构文档入口：

- [中文架构文档](zh-CN/README.md)
- [English architecture docs](README.en.md)

## 当前重点

第一阶段先记录 GitHub 组织架构、自动化流水线、app 发布生命周期和 taffish-hub 架构，因为它们是 `taf new`、`taf publish`、`taffish-index`、GitHub Actions、GHCR、Gitee mirror 和用户安装路径共同依赖的顶层设计。

后续可以继续补：

1. 中国镜像同步架构。
2. 官网和文档站点架构。
3. 维护者故障恢复手册。
