# taf-core Hub 系统

Hub 系统位于 `taf-core/hub/`，负责 TAFFISH 应用的索引、查询、搜索、安装、维护、卸载和定位。

## 作用

Hub 系统把 taf-app 从“本地项目”提升为“可发现、可安装、可更新的生态对象”。它不负责编译 TAF 语言本身，而是围绕已经发布的 package、artifact、version 和 command 建立索引与安装逻辑。

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `i18n.lisp` | 注册 Hub/package 人类消息，并把稳定 plan/status value 映射为本地化表现。 |
| `update.lisp` | 更新本地 hub index。 |
| `info.lisp` | 加载 index，解析 package、command、artifact、version。 |
| `search.lisp` | 搜索 index。 |
| `install.lisp` | 安装 hub package。 |
| `uninstall.lisp` | 卸载 package。 |
| `list.lisp` | 列出本地安装内容。 |
| `which.lisp` | 定位命令或安装路径。 |
| `upgrade.lisp` | 计划和执行 outdated/install-all/upgrade/prune 操作。 |
| `diagnostics.lisp` | 共享只读安装/索引证据分类和安全恢复建议。 |
| `repair.lisp` | 对显式 repair 目标安全分类，不放宽来源、身份或路径检查。 |

## index 契约

当前 `hub/info.lisp` 期望本地 index 使用 schema：

```text
taffish.index/v1
```

index 是 hub 系统最关键的外部契约之一。它连接 GitHub/Gitee 发布物、用户本地安装状态、
`taf` 命令查询行为、容器 digest/platform 元数据和声明式 smoke 元数据。

## 版本选择与安全清理

在线目标选择与本地排序是两件事：

- 未指定版本的 index 安装使用 `packages[name].latest`。批量安装、outdated 和
  upgrade 使用相同目标，不重新选择 index 中排序最大的版本。
- 精确目标已安装时，版本状态为 current，单独的验证证据决定警告或阻断写入；
  否则保留较新的本地版本，批量维护不自动降级。
- `taf-core/version.lisp` 提供内部统一比较器，供 Hub 排序、别名、维护和 publish
  的诊断性 tag 排序使用。数字段按整数比较：`a.7.10 > a.7.3`、`rc.10 > rc.2`、
  `r10 > r9`。数字主体的正式版高于对应预发布版，build metadata 不影响优先级。
  数字主体不强制三段，也对 `rc10`、`rc2` 这样的后缀进行自然数字比较。
- 其他格式若非数字结构相同，可自然比较；否则只有确定的展示顺序，不视为可靠的
  升级或删除依据。无法可靠判断升级时报告错误，不猜测。排序等价不代表安装身份相同。
- 无版本命令别名仍按上述排序指向本地已安装的最新版本，不依赖 index 是否存在或其 latest。

`prune` 首先要求同源 index.latest 已在本地安装且有效。只读验证保留目标的 wrapper、
冻结快照和 launcher，不执行它们。缺 index、记录、目标或目标损坏时跳过；包含私有
local-project 的包组也跳过，不改为保留本地最大版本。只删除同一规范仓库来源且可靠地
更旧的版本，保护未知/冲突来源、较新版本、顺序不明或排序等价的其他身份。没有构建
验证 manifest 的旧安装不能充当已验证的保留目标或删除候选。维护分组内任一已识别版本未验证、
无效或未知时，整个包受自动清理保护。先在相同作用域运行 `taf doctor hub APP --verbose`，
备份本地修改并确认来源后，再审阅精确版本的 `install --repair --dry-run` 计划。
repair 是显式 opt-in，不由 doctor 触发。`--all --repair` 仅选择已安装 index.latest；
`--all-installed --repair` 选择本地全部已安装版本（含历史版本）。两者都跳过 verified，
不新装版本或依赖、不升级；任一 blocked 目标阻断整批写入。
详见[修复策略](hub-maintenance.md#显式修复)。

`--prune-old` 仅对本次批量选择范围内成功安装或确认目标有效的包应用相同清理规则；
安装失败不进入清理。dry-run 与 MCP planner 不删除文件。清理不删除容器镜像，也不是
依赖感知的垃圾回收：Flow 可能仍明确引用旧命令。使用 `--yes` 前应审阅计划。

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
3. 安装、卸载、list、which、outdated、upgrade、prune 是否保持一致。
4. GitHub/Gitee 镜像是否都能正确解析。
5. 错误信息是否能帮助用户判断是网络问题、index 问题还是 package 问题。
6. 本地化文本是否仍与 index/install JSON、plan value、source URL 和原始 git/curl 输出隔离。

长期看，hub 系统需要单独文档化。这部分已经超出源码 dev 手册的第一阶段范围，但这里要保留清楚接口边界。
