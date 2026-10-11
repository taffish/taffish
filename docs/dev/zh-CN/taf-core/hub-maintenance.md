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

`hub-outdated` 和 `hub-upgrade` 以 index 的 `latest` record 作为在线目标。
该身份已经安装时视为 current，否则用统一版本比较器判断本地优先级，不自动降级。
如果本地安装 metadata 标记
`origin_kind = local-project`，则认为它是本地/私有安装，不会用公开 index 自动升级。

## Kind 过滤

批量操作支持 `:tool`、`:flow` 或 `:all`。

kind 优先来自 install metadata。对于旧安装，代码会回退到 index metadata，
或检查已安装源码项目。

`outdated` 和 `upgrade` 在验证安装文件、比较本地版本与 index latest 之前应用类型
筛选。被排除的 flow 不会阻断仅针对 tool 的计划，反向也一样。被选中的包及 `all`
仍执行原有验证和版本顺序检查；MCP 规划工具使用相同的 core 行为。

## Prune 语义

`hub-prune` 保留已安装、已验证、同源的 index `latest`，只移除可靠判定为更旧的同源版本。
私有/未知来源、较新及无法可靠比较的版本保持受保护。缺 index/latest/保留目标时不会
回退为“围绕本地最大版本清理”。维护分组内任一已识别安装为 unverified、invalid 或 unknown 时，
整个包均受自动清理保护；执行前再次验证保留目标和删除候选。
删除只涉及 TAFFISH install root 和 launcher，随后刷新无版本 alias。
这不是依赖感知的垃圾回收，授权删除前仍需检查 Flow 固定的版本依赖。

它不会删除共享容器镜像、Podman/Docker image store、Apptainer cache 或 SIF 文件。
镜像缓存可能被其他 app 或用户共享，所以本地 app prune 不负责 image cache 管理。

## 安装证据与恢复

`hub/diagnostics.lisp` 为维护命令和 `taf doctor hub` 提供共享只读验证，区分四种状态：

| 状态 | 证据 | 处理策略 |
| --- | --- | --- |
| `verified` | 必要本地文件齐全，与构建清单摘要一致。 | 仍需通过来源和版本安全检查。 |
| `unverified` | 结构完备，但旧清单缺失或启动器模板无法识别。 | 保留并警告，不阻断普通批量安装，不伪造证据。 |
| `invalid` | 必要文件缺失、元数据损坏、身份或摘要不一致。 | 阻止选中批量写入，不参与自动清理。 |
| `unknown` | 权限、越界链接、未知格式或检查失败导致无法下结论。 | 报告不确定性，不猜测或覆盖。 |

install-all 与 upgrade 在任何包写入前汇总选中安装的 invalid/unknown 问题。
outdated 仍是只读诊断计划。旧的 unverified 安装可与新安装版本共存，但
`--prune-old` 仍保护该包。版本状态 `current` 可以与验证状态 `unverified` 同时成立。

安装路径必须符合受管理的目录布局；删除前会重新读取安装记录。路径不一致时不自动
修复。显式卸载仍支持路径安全的旧记录，不要求构建清单。系统安装保存的自定义 bin
目录继续有效，但启动器名称必须与该目录及应用身份一致。

真实执行时，`--yes --json` 将安装和删除的嵌套结果输出为 JSON 对象，包含
`prune_result` 内的结果；布尔 `*_p` 字段仍为布尔值。dry-run 结果不表示已改变文件。

用 `taf doctor index --user` 检查本地索引，用
`taf doctor hub APP --user --verbose` 检查安装文件；系统安装使用 `--system`。
报告包含目标、作用域、稳定问题代码、路径、影响和处理建议。先备份有意修改，
再用精确版本的 `install APP VERSION-ID --repair --dry-run` 审阅重建计划。
权限或未知格式问题仍需先核对
所有权/兼容性，不能一律 chmod 或重装。私有安装应对照原本地来源排查，不能用公共索引覆盖。

验证不执行已安装 wrapper、不获取镜像，也不生成历史 manifest。
摘要一致只证明本地一致性，不证明官方身份、上游安全或运行时可用性。

维护命令保留既有 install metadata 枚举契约。`install.json` 无法读取或解析的目录，
应通过 doctor 专项扫描发现；这些未识别目录不是自动删除候选。

## 规划性能

`doctor hub`、`install --all`、`outdated` 和 `upgrade` 会批量探测选中的本地安装，
在同一次只读扫描内复用证据，而不是为每个安装重复启动完整扫描。
固定的 POSIX shell 脚本只读取路径属性和目录条目；路径作为独立参数传入，
不作为 shell 代码执行。结果以 NUL 分隔，按 UTF-8 读取，保留空格、中文和
文件名内的换行。冻结目录遍历不跟随子项软链接；探测失败或响应不完整不能
得出“已验证”的结论。

路径属性和目录列表只在一次只读规划中复用，构建清单摘要仍从实际文件计算。
不会写入持久化的“已经验证”缓存，删除前仍重新验证。下一次命令会重新读取
文件内容和权限，不会沿用上次的验证结果。

人类进度只写 stderr，显示阶段变化及验证已完成数/总数。交互式 stderr TTY 原地更新；
重定向日志逐行输出，计数更新约每秒最多一次，阶段变化和完成时也可能输出一行。
进度在批次或检查边界更新，不是后台定时器，不能预测剩余时间，也不能中断阻塞的文件
系统读取。非 TTY 流及 `TERM=dumb` 不收到光标控制序列。`--json`、`:verbose nil`
和 MCP 调用不输出进度文字。

性能目标是本地磁盘上约 300 个小型 app 的规划在几秒内完成，不是五秒超时，
也不是对所有机器的时间保证。冻结目录大小、磁盘延迟以及真正下载、安装有变化的
app 都会影响耗时。测试方式见[规模测试](../../../../test/README.md)。

## JSON 契约

普通维护结果（未设置 `:repair-p t`）使用机器可读 schema：

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

item 还增量提供 `validation` / `validations` 证据，包括 state、问题代码、路径和详情。
缺省可选值或空 issues 列表可能为 JSON `null`，调用者不能假设每个 item 都有验证信息。

典型 status 包括 `current`、`outdated`、`ahead`、`missing-index`、
`local-project` 和 `not-installed`。

典型 action 包括 `skip`、`install`、`upgrade`、`install-latest` 和
`remove-old`。

## 文本展示契约

结构化结果是真实数据源。JSON 输出应保留所有 item，包括 `current` 和 skipped
entries，方便自动化检查完整决策集合。

面向人的文本显示状态变化，隐藏健康且无变化的 item，不在验证摘要后重复打印 skip 行。
重复问题在所选作用域内按问题类型、验证状态和处理策略分组，包含计数及每组至多三个例子；
处理建议按策略合并，不为每个 app 重复。应用数、安装身份数和问题数是不同计数，
同一个身份可能有多个问题。`no changes` 不会掩盖警告或阻断项。

`taf doctor hub --verbose` 保留逐项检查及依据；`--json` 保留全部结构化条目和问题。
摘要不会截断底层结果。共享显示宽度 helper 使用保守 Unicode 宽度，不按语言补空格；
长字段或复杂文本退回 label/value 分行，字段值不截断。

## 显式修复

`install --repair` 必须显式选择，不由 doctor 或普通安装自动触发。以下示例用于当前用户；
系统安装改用 `--system`，执行时还需相应写权限：

```sh
taf install APP --repair --user --dry-run
taf install APP1 APP2 --repair --user --dry-run
taf install APP 1.4.0-r1 --repair --user --dry-run
taf install --all --repair --tools --user
taf install --all --repair --tools --user --yes
taf install --all-installed --repair --user
taf install --all-installed --repair --user --yes
```

批量修复有两种选择方式：`--all --repair` 只检查已安装的 `index.latest`，
未安装的最新版会跳过，不会补装。`--all-installed --repair` 从本地枚举全部已安装版本，
包括历史版本；不升级、不安装缺失版本或依赖、不清理。两者都默认预览，确认后加
`--yes` 才执行，也都支持 `--json`、作用域和类型筛选。两种选择器不能并用，也不能与
显式目标并用；`--all-installed` 必须配合 `--repair`。显式版本目标使用 `--dry-run`
预览，去掉该参数即执行。已通过验证的目标跳过。

缺失或不可读的安装记录、已不在索引中的版本会保留为受阻目标，不会静默漏掉。
无法确定类型的目标不能被类型筛选静默排除，私有安装不从公共索引覆盖。
修复不能与 `--force`、`--from`、`--prune-old` 组合。

整个选中批次先完成只读预检，再允许变更；任一目标受阻时整批不写入。只有索引来源
与身份匹配、受管理路径安全、命令入口可识别且源码 commit 固定，才可重建。
旧清单缺失只能由重新构建并验证产生新证据，不能伪造历史摘要。未知元数据格式、私有/未知/
冲突来源、自定义命令入口、不安全或不可读路径均拒绝覆盖。

每项修复使用备份、暂存、切换前验证及最终验证；失败回滚该项变更并保留恢复材料。
运行中断保留事务日志并阻止盲目重试。应保留日志和备份供恢复核对，不能通过删除
它们绕过保护；这里不把恢复目录布局或具体操作步骤定义为公开 API。整批 **不是原子事务**：
后续失败会停止剩余操作，但不会撤销先前成功的修复。修复与普通 install/uninstall/prune
共用 home/bin 协作写锁，不改变删除策略。不承诺断电后的持久性、崩溃自动恢复或零停机，
也不保证旧客户端遵守新锁，应避免旧客户端并发写入。

core 的 `hub-install`、`hub-install-many`、`hub-install-all` 接受可选 `:repair-p`
（默认 `nil`）。repair 返回 `taffish.repair-plan/v1`，普通调用的返回契约不变。
不新增 MCP repair tool、参数或执行入口；既有 MCP 写能力不变，维护 planner 仍为 dry-run。

修复 JSON 的 `selection` 为 `index-latest`、`installed-all-versions` 或 `explicit`。
core 的 `hub-install-all` 接受可选 `:all-installed-p nil`，仅配合 `:repair-p t`；
不删除既有参数或结果字段。

## 修改指南

修改这一层时要检查：

1. dry-run 绝不能写文件。
2. `--yes` 行为必须显式且有测试。
3. 本地/私有 `--from` 安装不能被公开 index 静默升级。
4. `install.json` 兼容性很重要，因为 list、which、uninstall、outdated、upgrade、
   prune 都会消费它。
5. 既有 MCP 维护 planner 保持只读/dry-run，不暴露 repair 入口，既有写工具不变。

## 操作状态提示

慢操作会在 stderr 提示当前目标与阶段。TTY 更新、日志限频、目标计数的含义、
静默/JSON 行为及限制见[命令状态与进度](command-progress.md)。提示不改变校验、写操作、重试或退出码规则。
