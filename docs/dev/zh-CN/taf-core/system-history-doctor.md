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

`system-history` 支持：

| 参数 | 行为 |
| --- | --- |
| `:last` | 返回最后 N 行，默认 20。 |
| `:id` | 按 id 过滤。 |
| `:json-p` | 原样输出 JSONL。 |
| `:path-p` | 只输出 history 文件路径。 |
| `:clear-p` | 清空 history。 |

history 查询使用轻量字符串字段提取，不是完整 JSON 查询引擎。

## doctor 的作用

doctor 诊断八组状态：

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

默认文本保持简洁，只显示需要处理或暂时无法确认的诊断。`--verbose`
增加 evidence、remediation 和文档链接。`--json` 按
`taffish.doctor/v1` 输出稳定的英文 key。

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

## 修改指南

修改 history 或 doctor 时要检查：

1. build wrapper 写出的 history 字段仍兼容。
2. 新 home 目录与 required-dir list 保持同步。
3. 诊断保持统一 item schema 和 legacy result fields。
4. probe 有时间上限、无交互、无自动修复副作用。
5. CLI help、completion、MCP 投影、测试和中英文文档保持同步。
6. process/path/permission 变化经过 macOS/SBCL 与 Linux/LispWorks 验证。
