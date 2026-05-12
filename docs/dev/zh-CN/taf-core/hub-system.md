# taf-core Hub 系统

Hub 系统位于 `taf-core/hub/`，负责 TAFFISH 应用的索引、查询、搜索、安装、卸载和定位。

## 作用

Hub 系统把 taf-app 从“本地项目”提升为“可发现、可安装、可更新的生态对象”。它不负责编译 TAF 语言本身，而是围绕已经发布的 package、artifact、version 和 command 建立索引与安装逻辑。

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `update.lisp` | 更新本地 hub index。 |
| `info.lisp` | 加载 index，解析 package、command、artifact、version。 |
| `search.lisp` | 搜索 index。 |
| `install.lisp` | 安装 hub package。 |
| `uninstall.lisp` | 卸载 package。 |
| `list.lisp` | 列出本地安装内容。 |
| `which.lisp` | 定位命令或安装路径。 |

## index 契约

当前 `hub/info.lisp` 期望本地 index 使用 schema：

```text
taffish.index/v1
```

index 是 hub 系统最关键的外部契约之一。它连接 GitHub/Gitee 发布物、用户本地安装状态、
`taf` 命令查询行为、容器 digest/platform 元数据和声明式 smoke 元数据。

## GitHub 与 Gitee

当前项目设计中，GitHub 组织为 `taffish`，Gitee 组织为 `taffish-org`。这两个名字不是同一个，应避免在代码和文档中混用。

Gitee 镜像主要服务中国用户的访问稳定性。hub 系统和系统配置层需要支持 source rewrite 或 index URL 配置，使用户可以在不同网络环境下获得一致的 `taf` 使用体验。

## 与系统配置的关系

Hub 行为会读取系统配置，例如：

1. index URL。
2. source rewrite 规则。
3. GitHub/Gitee host 和 owner。
4. 用户覆盖的环境变量。

这些默认值主要由 `taf-core/system/config.lisp` 维护。hub 文件不应到处硬编码镜像规则。

## 修改指南

修改 hub 系统时应检查：

1. index schema 是否变化。
2. 本地缓存路径是否变化。
3. 安装、卸载、list、which 是否保持一致。
4. GitHub/Gitee 镜像是否都能正确解析。
5. 错误信息是否能帮助用户判断是网络问题、index 问题还是 package 问题。

长期看，hub 系统需要单独文档化。这部分已经超出源码 dev 手册的第一阶段范围，但这里要保留清楚接口边界。
