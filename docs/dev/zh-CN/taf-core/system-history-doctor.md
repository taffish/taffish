# system/history 与 doctor

`system/history.lisp` 记录 TAFFISH 命令执行历史；`system/doctor.lisp`
以只读优先的方式诊断本机 TAFFISH 环境。

## history 的作用

history 在 active user home 下写入 JSONL 文件：

```text
logs/history.jsonl
```

build wrapper 执行时会写入 runtime history。

`system-record-history-event` 接收 event、status、project、command、args、
cwd、backend、exit code、extra metadata 和 taf version。project 会展开为
name、kind、version、release、command、root、main path、repository URL 和
container image。默认 `safe t`，写入失败返回 nil，不中断主流程。

wrapper 以 NUL 分隔字段，将原始参数及其数量交给配套的 `taffish`。接收端核对参数数量，
编码成一行 UTF-8 JSONL，ID 保留 wrapper 的 PID。原生 `taf` 和 wrapper 共用
`%history-append-line`。独立锁文件在清空历史后保留，确保 `--clear` 与随后打开历史文件
的写入进程使用同一把锁。详见[历史记录规范](../../../standards/zh-CN/history-spec.md)。

`system-history` 支持：

| 参数 | 行为 |
| --- | --- |
| `:last` | 返回最后 N 行，默认 20。 |
| `:id` | 按 id 过滤。 |
| `:json-p` | 原样输出 JSONL。 |
| `:path-p` | 只输出 history 文件路径。 |
| `:clear-p` | 清空 history。 |

history 查询使用轻量字符串字段提取，不是完整 JSON 查询引擎。

history header、label、空状态文本和 clear 结果使用当前解析出的人类语言。原始 JSONL 输出、
event field、ID、status、command 与落盘记录保持语言不变。

## doctor 的作用

默认环境检查诊断八组状态，不对全部 app 做摘要扫描：

1. TAFFISH home 目录与权限。
2. effective config 是否可解析。
3. 本地 index snapshot。
4. 核心命令和 app command 路径。
5. Bash、Zsh 或 Fish completion 的安装与可确认激活状态。
6. Vim/Neovim runtime 文件与可确认激活状态。
7. user/system Apptainer SIF cache 策略。
8. 有时间上限的 Docker、Podman 和 Apptainer readiness probe。

CLI：

```text
taf doctor [--user | --system] [--init]
           [--shell auto|bash|zsh|fish]
           [--json | --verbose]
```

默认文本保持简洁，只显示需要处理或暂时无法确认的诊断，并直接给出处理建议。
`--verbose` 增加详细证据和文档链接。`--json` 按
`taffish.doctor/v1` 输出稳定的英文 key。

人类文本跟随 `taffish.i18n` 解析出的语言，并内置中英文 summary 与 remediation。
diagnostic plist 和 `--json` payload 刻意保留规范英文 id、status value、evidence 和机器字段；
本地化不会改变 detector 逻辑。

## 诊断契约

每个诊断 item 使用以下 additive 结构：

```lisp
(:id ...
 :status :ok|:warning|:error|:unknown|:not-applicable
 :scope :user|:system
 :summary ...
 :evidence ...
 :remediation ...
 :docs-url ...)
```

`system-doctor` 保留原有 `:directories`、`:executables`、`:paths` 和 legacy
`:status` 字段，并新增 `:diagnostics` 与 `:diagnostic-status`。JSON 会把连字符
转换为下划线，例如 `:shell-completion` 对应 `shell_completion`。

诊断状态含义：

| 状态 | 含义 |
| --- | --- |
| `:ok` | 适用检查通过。 |
| `:warning` | 当前仍可使用或可恢复，但需要关注。 |
| `:error` | 当前策略不安全或不可用。 |
| `:unknown` | 文件或命令存在，但无法证明激活或 readiness。 |
| `:not-applicable` | 该能力未安装或不适用。 |

`unknown` 不等于成功。例如 completion 源文件存在，并不能证明当前 shell
已经加载它们。

## 离线索引与安装检查

```sh
taf doctor index --user
taf doctor hub --system
taf doctor hub APP taf-APP-v1.4.0-r1 --user --verbose
taf doctor hub APP --user --json
```

`index` 读取所选作用域的 `index/current.json`，检查可读性、JSON/schema、包结构、
latest 引用和对应记录身份，不下载替代内容。缺索引为 warning；格式损坏为 error；
不支持的 schema 或无法读取的证据为 unknown。

`hub` 还检查该作用域的已安装 app。目标可以是应用名、基础命令或带版本命令，
不指定目标则检查全部安装。损坏的 `install.json` 不会被静默忽略；没有 index 时仍能
检查本地文件。检查覆盖必要 wrapper/launcher、冻结项目文件、身份和 `.taf-build.json`
摘要。读取快照前检查权限和链接；越界或不支持的链接报告 unknown，不执行其内容。
扫描使用本地 `test` 及 BSD/GNU `find`，不把 app 输入交给 shell 求值。

每个安装的 `inspection.state` 为 `verified`、`unverified`、`invalid`、`unknown`，
分别对应诊断 `ok`、`warning`、`error`、`unknown`。必要结构完备时，旧清单缺失或
启动器模板无法识别属于未验证；必要文件缺失、摘要不符属于无效。
`issues` 包含稳定代码、路径和可选详情；空列表可能是 JSON `null`。
版本/来源状态单独表示：verbose/JSON 中的 `index_latest`、`source_status` 是证据，
不是官方认证。本地验证通过也不代表容器可运行。

安装记录中的路径必须与实际受管理的目录布局一致。路径不一致或 `install.json`
声明了未知格式时为 `unknown`；旧记录缺少格式声明时为 `unverified`，均不作为自动
清理依据。`apps` 目录不存在表示没有安装；该位置是文件、链接或不可读取的目录时，
则报告问题，不将其当作空安装。

不带版本号的命令快捷入口单独报告为 `hub_command`。入口缺失或内容无法识别时发出
警告，但不改变 `hub_installation` 的产物完整性结论。存在多个版本时，按本地别名
选择规则检查，不要求入口同时指向每个版本。doctor 不执行或改写入口；`--verbose`
使用 JSON 展示检查依据。

Hub 默认文本在所选作用域内按问题类型/状态和处理策略汇总重复问题，每组保留计数及至多
三个例子，不为每个 app 重复建议。`--verbose` 与 `--json` 保留逐项完整检查依据；
摘要渲染不会删除返回结果中的条目。

按照报告的作用域和路径决定恢复方式。先备份本地修改，用
`taf install APP VERSION-ID --repair --user --dry-run`（或 `--system`）预览并核对安全分类。
旧安装须明确指定精确版本。doctor 不调用 repair，也不补写旧清单。repair 拒绝私有来源、
自定义 launcher 和未知 schema；权限与兼容性仍需所有者核对。全部目标选择、只读预检
及事务限制见[显式修复](hub-maintenance.md#显式修复)。

专项模式拒绝 `--init` 和 `--shell`，不探测 backend，不执行 app、不联网、不改文件或权限。
在 `taffish.doctor/v1` 中增量增加 `check` 和 `exit_code`：出现 error/unknown 时退出 1，
否则退出 0（包括 warning）；检查失败仍输出 JSON。默认环境检查的旧退出行为不变。

Hub 诊断在同一次只读扫描内复用批量路径、目录及 alias 证据，保留构建清单摘要校验，
不使用持久化验证缓存。`taf doctor hub APP` 在深扫前筛选目标；为判断本地快捷入口，
alias 检查可能读取同组其他版本的元数据。未知 schema 和 unsafe 路径不深扫；定向扫描
受阻时报告 unknown，不误报目标不存在。人类 stderr 显示阶段/计数，TTY 原地更新，
日志限频，详见[批量维护](hub-maintenance.md#规划性能)。JSON/MCP 无进度文字。
字段采用共享的保守 Unicode 排版，长或复杂文本退回分行，不按语言补空格或截断路径。

## executable 与 backend 检查

`git` 仍是 required。`gh`、容器后端、squashfs helper、`taf`、`taffish`、
Vim 和 Neovim 都按能力检查。Docker、Podman 和 Apptainer readiness command
禁用 stdin，并设置短 timeout。doctor 不会启动 daemon、创建 Podman machine、
拉取镜像或运行容器。

## Apptainer SIF 策略

doctor 识别以下合理策略：

1. 用户可写的独立 SIF cache。
2. mode 为 `1777`、带 sticky bit 的共享 system cache。
3. 管理员预填充、普通用户只读的 system cache，同时存在可写 user fallback。

system cache 对所有用户可写但没有 sticky bit 时属于 error。doctor 只报告权限，
不会运行 `chmod`、`chown` 或 `sudo`。

## 副作用边界

除非显式使用 `:init-p t` / `--init`，doctor 完全只读。初始化只创建 TAFFISH
自己的 required directories，不修改 shell rc、Fish 配置、Vim/Neovim 配置、
系统配置、ownership、permissions、daemon 或 container state。system scope
初始化仍然要求 root。

## API 控制项

`system-doctor` 新增以下可选 keyword：

| 参数 | 行为 |
| --- | --- |
| `:shell` | `:auto`、`:bash`、`:zsh` 或 `:fish`。 |
| `:detail-p` | 在人类文本中显示详细 evidence。 |
| `:json-p` | 启用输出时渲染 `taffish.doctor/v1` JSON。 |
| `:verbose` | 控制是否渲染；result plist 始终返回。 |
| `:check` | 默认 `:environment`；`:index`、`:hub` 选择离线检查，也接受对应字符串。 |
| `:targets` | 仅 `:check :hub` 可用，非空字符串组成的可选列表。 |

## 修改指南

修改 history 或 doctor 时要检查：

1. build wrapper 写出的 history 字段仍兼容。
2. 新 home 目录与 required-dir list 保持同步。
3. 诊断保持统一 item schema 和 legacy result fields。
4. probe 有时间上限、无交互、无自动修复副作用。
5. CLI help、completion、MCP 投影、测试和中英文文档保持同步。
6. process/path/permission 变化经过 macOS/SBCL 与 Linux/LispWorks 验证。
7. 人类翻译与稳定英文 JSON 分别有回归测试。


### 理解 Hub 诊断计数

人类报告区分已枚举的应用/版本数、涉及问题的应用/版本数以及问题项数。
一个版本可以有多个问题。不可读或不安全路径会提示检查不完整；枚举数量不代表
全部验证通过。`--verbose` 和 JSON 保留完整证据。旧构建清单缺失表示未验证，不表示已损坏。

需要同时检查历史版本的修复时，使用 `taf install --all-installed --repair --user`
（系统安装改用 `--system`），完整审阅计划后才加 `--yes`。`--all --repair` 仍只选择
已安装的 index.latest。doctor 本身不会执行这两种修复。
