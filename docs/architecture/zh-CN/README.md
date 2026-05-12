# TAFFISH 架构文档

本目录记录 TAFFISH 生态层架构。它不是用户手册，也不是源码开发手册，而是解释 TAFFISH 如何作为一个多仓库、多发布物、多镜像源的系统运转。

## 当前文档

- [GitHub 组织架构](github-organization.md)
- [自动化流水线架构](automation-pipelines.md)
- [app 发布生命周期](app-release-lifecycle.md)
- [taffish-hub 架构](taffish-hub-architecture.md)

## 架构层级

TAFFISH 生态可以分为五层：

| 层级 | 代表对象 | 主要责任 |
| --- | --- | --- |
| 核心分发层 | `taffish/taffish` | 分发 `taf`、`taffish`、`taffish-mcp`、安装脚本、补全、编辑器文件和二进制 release。 |
| 应用源码层 | `taffish/<app>` | 每个 taf-app 的源码、tag、release、Actions 和容器镜像。 |
| 索引层 | `taffish/taffish-index` | 发布静态 JSON index，供本地 `taf` 命令消费。 |
| 展示层 | `taffish.github.io` / `taffish/taffish.github.io` | Web Hub，用于浏览 app、版本、依赖和安装命令。 |
| 镜像层 | `gitee.com/taffish-org/*` | 服务中国用户的读取、安装和 source rewrite。 |

自动化流水线横跨这些层级：app 仓库自己发布 GHCR 镜像，`taffish-index` 扫描 canonical GitHub 组织并生成静态 index，Web Hub 读取 index 展示，Gitee 镜像同步只改变访问路径，不改变 canonical 身份。

app 发布生命周期则把这些层级串成维护者的实际路径：从 `taf new`、`taf check`、`taf publish`，到 GHCR、index、Gitee mirror 和用户侧安装验证。

`taffish-hub` 架构解释维护者本地工厂如何组织 app staging、index、Web Hub、公开文档、官网、upstream 更新队列和归档快照。

## 与规范的关系

架构文档描述“哪些东西放在哪里、如何流动”。具体格式仍以规范文档为准：

1. hub index schema 见 [hub index 规范](../../standards/zh-CN/hub-index-spec.md)。
2. app 项目格式见 [TAFFISH 项目规范](../../standards/zh-CN/taffish-project-spec.md)。
3. 配置和 source rewrite 见 [TAFFISH 配置规范](../../standards/zh-CN/system-config-spec.md)。
4. 安装元数据见 [TAFFISH 安装元数据规范](../../standards/zh-CN/install-metadata-spec.md)。
5. MCP 接口见 [TAFFISH MCP 接口规范](../../standards/zh-CN/mcp-interface-spec.md)。
