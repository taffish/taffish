# hub/outdated、install-all、upgrade、prune

`hub/upgrade.lisp` 保存基于现有 index 和 install metadata 的本地包维护逻辑。

## 作用

这些 API 回答四类问题：

1. 哪些已安装 app 旧于本地 index？（`hub-outdated`）
2. 如果安装 index 中所有 app，会发生什么？（`hub-install-all`）
3. 如果把本地 app 升级到 index latest，会发生什么？（`hub-upgrade`）
4. 哪些本地旧版本可以安全移除？（`hub-prune`）

这些命令有意保持保守。CLI 层的 `install-all`、`upgrade` 和 `prune` 默认都是
dry-run，只有显式传入 `--yes` 才会修改本地文件。

## Scope 和输入

所有维护 API 都只作用于一个 TAFFISH home scope：

```text
:user   -> TAFFISH user home
:system -> TAFFISH system home
```

它们读取：

1. `index/current.json`
2. `apps/*/*/install.json`
3. 本地 install metadata 中的 package name、command name、version、origin、kind 等字段

`hub-outdated` 和 `hub-upgrade` 会把每个 package 的本地最新安装版本和 index
中的 `latest` record 比较。如果本地安装 metadata 标记
`origin_kind = local-project`，则认为它是本地/私有安装，不会用公开 index 自动升级。

## Kind 过滤

批量操作支持 `:tool`、`:flow` 或 `:all`。

kind 优先来自 install metadata。对于旧安装，代码会回退到 index metadata，
或检查已安装源码项目。

## Prune 语义

`hub-prune` 会移除本地旧 app 版本，只保留每个 app 的本地最新版本。它会删除
TAFFISH install root 和 launcher，并刷新不带版本号的 command alias。

它不会删除共享容器镜像、Podman/Docker image store、Apptainer cache 或 SIF 文件。
镜像缓存可能被其他 app 或用户共享，所以本地 app prune 不负责 image cache 管理。

## JSON 契约

维护结果使用机器可读 schema：

```text
taffish.package-plan/v1
```

每个结果包含：

1. operation
2. scope 和 home
3. kind filter
4. dry-run / yes / prune-old 标记
5. summary 计数
6. 每个 item 的 status 和 action

典型 status 包括 `current`、`outdated`、`ahead`、`missing-index`、
`local-project` 和 `not-installed`。

典型 action 包括 `skip`、`install`、`upgrade`、`install-latest` 和
`remove-old`。

## 文本展示契约

结构化结果是真实数据源。JSON 输出应保留所有 item，包括 `current` 和 skipped
entries，方便自动化检查完整决策集合。

面向人的文本输出则应更安静。它只展示会改变本地状态的 item；如果所有 item 都被
skipped，则输出 `no changes`。这样批量维护命令在 shell 会话中不会刷屏，同时
`--json` 仍然保留完整机器可读细节。

## 修改指南

修改这一层时要检查：

1. dry-run 绝不能写文件。
2. `--yes` 行为必须显式且有测试。
3. 本地/私有 `--from` 安装不能被公开 index 静默升级。
4. `install.json` 兼容性很重要，因为 list、which、uninstall、outdated、upgrade、
   prune 都会消费它。
5. MCP 对这些操作只能暴露只读或 dry-run planner。
