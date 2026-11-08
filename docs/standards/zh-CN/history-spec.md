# TAFFISH History 规范

本页定义 TAFFISH history 的持久化格式和 wrapper 写入契约。

## 文件位置

history 文件位于用户 home：

```text
<user-home>/logs/history.jsonl
```

当前 history 总是写入 user home，而不是 system home。可以通过环境变量或 wrapper 内部变量调整具体文件路径。

## 文件格式

history 使用 JSON Lines，每一行是一个 JSON object。

```json
{"id":"20260510T120000-1A2B","time":"2026-05-10T12:00:00Z","event":"exec","status":"success"}
```

每条记录应独立可解析。追加失败不应影响主命令运行。

当前 wrapper 和原生 `taf` 写入端先准备完整记录，再取得 `<历史文件>.lock` 的独占锁，
随后打开历史文件并追加整行。`taf history --clear` 使用同一把锁，清空后保留锁文件。
持锁范围仅限历史文件操作，工具可以并行运行。等待锁超过 5 秒时跳过本条记录，工具
保留自身退出码。共享历史的各进程应使用同一历史文件路径，文件系统须支持进程间文件锁。

## 时间与 ID

`time` 使用 UTC：

```text
YYYY-MM-DDTHH:MM:SSZ
```

内部 Lisp 写入的 `id` 形如：

```text
<compact-time>-<PID 的 36 进制表示>-<进程内计数的 36 进制表示>
```

wrapper shell 写入的 `id` 形如：

```text
<compact-time>-<pid>
```

两者都只承诺在日常使用中便于追踪，不承诺全局唯一。

## 通用字段

history event 可以包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | string | event id。 |
| `time` | string | UTC 时间。 |
| `event` | string | 事件类型，例如 `exec`。 |
| `status` | string | `success`、`failure` 或其他状态。 |
| `command` | string | 命令或 artifact 名。 |
| `args` | array | 参数列表。 |
| `cwd` | string | 当前工作目录。 |
| `backend` | string/null | 运行后端。 |
| `exit_code` | number/null | 退出码。 |
| `taf_version` | string/null | TAFFISH 版本信息。 |

空值字段可以被省略。读取端不能假设所有字段都存在。

## 项目字段

当 event 与项目有关时，可以包含：

| 字段 | 类型 | 来源 |
| --- | --- | --- |
| `project_name` | string | `[package].name`。 |
| `project_kind` | string | `[package].kind`。 |
| `project_version` | string | `[package].version`。 |
| `project_release` | number/string | `[package].release`。 |
| `project_command` | string | `[command].name`。 |
| `project_root` | string | 项目根或 snapshot root。 |
| `project_main` | string | 主 TAF 路径。 |
| `repository_url` | string/null | `[repository].url`。 |
| `container_image` | string/null | `[container].image`。 |

## wrapper 写入字段

build 生成的 command wrapper 在执行时会写入：

| 字段 | 说明 |
| --- | --- |
| `event` | 固定为 `exec`。 |
| `stage` | `compile`、`chmod` 或 `run`。 |
| `snapshot_root` | wrapper 使用的项目 snapshot。 |
| `history_backend` | 固定为 `shell-wrapper`。 |

wrapper 在编译失败、chmod 失败和运行结束时都会尝试记录 history。
它通过私有管道将原进程 PID、项目字段和参数交给配套的 `taffish` 可执行程序。
升级 `taf` 和 `taffish` 后，在已有源码项目中运行 `taf build` 重新生成 wrapper。
旧的生成脚本仍使用构建时的写入方式。

## 控制变量

wrapper 识别：

| 变量 | 说明 |
| --- | --- |
| `TAF_HISTORY_MODE` | `async`、`sync`、`off` 或 `0`。默认 `async`。 |
| `TAFFISH_USER_HOME` | 默认 history home。 |
| `TAF_HISTORY_FILE` | 覆盖具体 history 文件路径。 |

`async` 模式下，后台写入进程会断开与调用方标准流的连接。即使它正在等待历史文件锁，
调用方也能把 stdout 和 stderr 读到 EOF，并取得工具的退出码。历史记录可能在 wrapper
退出后才出现。需要在退出前等待本次写入尝试结束时，使用 `sync`。

## 读取行为

`taf history` 应支持：

1. 输出 history 文件路径。
2. 按最后 N 行读取。
3. 按 id 过滤。
4. 以原始 JSONL 输出。
5. 清空 history 文件。

读取端当前以轻量字符串方式提取 summary 字段，因此 history 格式应保持简单。未来如果改为严格 JSON 解析，应继续兼容已有 JSONL。

## 兼容性要求

history 是诊断和可追踪性数据，不应成为主运行路径的强依赖。写入失败必须尽量安全吞掉。

长期应保持：

1. JSONL 格式。
2. `id`、`time`、`event`、`status` 的基本含义。
3. `exec` event 的 `command`、`args`、`cwd`、`exit_code`。
4. wrapper 写入失败不影响命令退出码。
