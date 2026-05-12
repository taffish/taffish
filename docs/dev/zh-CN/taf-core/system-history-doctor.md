# system/history 与 doctor

`system/history.lisp` 记录 TAFFISH 命令执行历史。`system/doctor.lisp` 检查本机环境是否适合运行 TAFFISH。

## history 的作用

history 写入 JSONL 文件：

```text
logs/history.jsonl
```

默认位于 user home 下。build wrapper 会在执行时写入运行历史。

## history event

`system-record-history-event` 支持字段：

1. event。
2. status。
3. project。
4. command。
5. args。
6. cwd。
7. backend。
8. exit-code。
9. extra。
10. taf-version。

如果传入 project，会展开记录：

1. project name。
2. kind。
3. version。
4. release。
5. command。
6. root。
7. main。
8. repository URL。
9. container image。

默认 `safe t`，写入失败会返回 nil 而不是中断主流程。

## history 查询

`system-history` 支持：

| 参数 | 行为 |
| --- | --- |
| `:last` | 返回最后 N 行，默认 20。 |
| `:id` | 按 id 过滤。 |
| `:json-p` | 原样输出 JSONL。 |
| `:path-p` | 只输出 history 文件路径。 |
| `:clear-p` | 清空 history。 |

当前 history 查询使用轻量字符串字段提取，不是完整 JSON parser。这对日志浏览足够，但不应承担复杂分析。

## doctor 的作用

doctor 检查：

1. 必需目录是否存在。
2. 目录是否可写。
3. 必需或可选 executable 是否存在。
4. command bin 是否在 PATH。

`--init` 会创建缺失目录。system scope init 需要 root。

## executable 检查

当前检查：

| 程序 | 要求 |
| --- | --- |
| `git` | required |
| `gh` | optional |
| `docker` | optional |
| `podman` | optional |
| `apptainer` | optional |
| `mksquashfs` | optional |
| `squashfuse` | optional |
| `fuse2fs` | optional |
| `gocryptfs` | optional |
| `taffish` | optional |

git 是 publish/install clone 等流程的基础，所以是 required。

## doctor 状态

doctor 总状态可能是：

| 状态 | 含义 |
| --- | --- |
| `:error` | 创建或检查目录出错。 |
| `:needs-init` | 目录或 path 缺失，需要 init。 |
| `:permission-warning` | 目录或 bin 不可写。 |
| `:missing-tools` | 缺少 required executable。 |
| `:path-warning` | bin 不在 PATH 中。 |
| `:ok` | 环境可用。 |

## 修改指南

修改 history/doctor 时要检查：

1. build wrapper 写出的 history 字段是否仍兼容。
2. 新增目录是否同步到 home required dirs。
3. 新增外部依赖是否加入 doctor。
4. doctor 的状态优先级是否能给用户正确修复建议。
5. history 写入失败不应影响正常运行，除非用户显式要求严格模式。
