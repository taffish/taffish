# han.host 宿主适配层

`han.host` 是 han 最底层的宿主实现适配层。它隐藏 SBCL、LispWorks 等 Common Lisp 实现之间的差异。

## 作用

TAFFISH 要构建二进制命令行工具，不能让上层到处出现 `#+sbcl`、`#+lispworks` 条件代码。`han.host` 把这些差异集中处理。

## 支持实现

当前声明支持：

```text
SBCL, LispWorks, ECL, CCL
```

ECL 后端要求 macOS 或 Linux 上的 Unicode ECL，CCL 后端要求这两个系统上的 64 位 Clozure CL。各平台的官方构建实现见[源码构建指南](../build-from-source.md)。

不支持的实现会加载 `unsupported.lisp`，调用相关函数时抛出 `unsupported-host-function`。

## 通用能力

`common.lisp` 提供：

1. `host-process` 统一结构。
2. cwd。
3. 文件存在、目录存在。
4. 目录文件和子目录枚举。
5. copy-file。
6. delete-directory-tree。
7. temporary-directory。
8. POSIX shell token escape。
9. 同步进程运行需要的临时输入输出文件机制。

## Runtime I/O 与终端检测

| API | 作用 |
| --- | --- |
| `configure-runtime-io` | delivered CLI 处理用户文本前配置实现相关字符 I/O。LispWorks 会选择 UTF-8 控制台 I/O。SBCL、CCL 和 ECL 无需在这里额外设置。 |
| `standard-input-terminal-p` | 判断文件描述符 0 是否为终端，使命令可以区分交互式 stdin 与真实管道输入。 |
| `standard-error-terminal-p` | 查询进程 stderr（文件描述符 2）是否为终端，不读写、不启动子进程。 |
| `append-utf8-line` | 追加 UTF-8 字节和换行，遇到短写时继续写入剩余部分。 |
| `atomic-replace-file` | 将已写完的普通文件在同一文件系统内原子切换到指定名称。参数依次为源和目标的字面路径字符串。成功返回 `T`；跨文件系统或目标为目录时发出 `file-error`。 |
| `call-with-exclusive-file-lock` | 在给定的固定路径上持操作系统独占锁，调用零参函数。默认最多等待五秒。 |

这些函数刻意属于 host 层。上层不能直接重复 SBCL/LispWorks 的终端检测或 console encoding
配置。

`standard-error-terminal-p` 查询 fd 2，不是动态绑定后的 `*error-output*`。
支持的宿主对已关闭或非终端描述符返回假；不支持的实现抛出 `unsupported-host-function`。
它不查询终端尺寸或光标能力。进度调用方使用原地渲染前还须检查实际输出流和 `TERM=dumb`；
重定向日志限频逐行输出，JSON/MCP 调用方禁止人类进度。
LispWorks 的 UTF-8 输出流按实际文件描述符实现 `interactive-stream-p`，
区分终端、管道和已关闭的流，避免交付后的终端进度被误判为日志输出。

并发写 JSONL 的进程在整个 `append-utf8-line` 调用期间持同一把独占锁，直至写完
可能发生的短写。父目录缺失时会先创建；如果另一进程恰好先创建了同一父目录，
只容忍这一种竞态。其他路径或权限错误仍会从目录准备或追加操作中正常抛出。

## process API

### 可执行程序错误边界

三个 CLI 入口使用 host 内部错误边界包裹 runtime I/O 和语言初始化。逃逸的错误
使用原有命令错误前缀写入 stderr，并以状态码 1 退出。如果 stderr 或 condition 的
打印函数再次失败，只尽力报告，然后仍然以失败退出；包括 MCP stdio 模式在内，
都不使用 stdout 作为错误输出的备用通道。

SBCL 的交互中断在这一边界处理，不显示运行时回溯，并保留退出码 1。
LispWorks 保留已有中断处理，包括 SIGINT 时向 stdout 打印固定的
`Interrupted - quitting` 提示；CLI 不替换 LispWorks 全局信号处理器。
SIGTERM 行为不变。这不保证覆盖原生崩溃或运行时
资源耗尽等异常。

该边界是内部实现，不是导出的 han API；它不屏蔽 warning，不改变库函数的
condition 处理方式，也不改变正常 CLI/MCP 响应契约。

### 进程操作

| API | 作用 |
| --- | --- |
| `run-program` | 启动外部进程，返回 `host-process`。 |
| `run-program-sync` | 同步运行命令，返回 stdout、stderr、exit-code。 |
| `process-status` | 返回 `:running`、`:exited` 或 `:unknown`。 |
| `process-exit-code` | 获取退出码。 |
| `process-wait` | 等待进程结束。 |
| `process-close` | 关闭相关 stream/resource。 |

## SBCL 实现

SBCL 使用：

1. `sb-ext:*posix-argv*`
2. `sb-ext:posix-getenv`
3. `sb-ext:exit`
4. `sb-ext:run-program`
5. `O_APPEND` 配合 `write(2)` 写入完整 UTF-8 日志记录

同步运行会把 stdout/stderr 捕获到临时文件，再读回字符串或 replay 到 stream。

## LispWorks 实现

LispWorks 使用：

1. `sys:*line-arguments-list*`
2. `lw:environment-variable`
3. `lw:quit`
4. `system:run-shell-command`
5. `system:pipe-exit-status`
6. C append mode 配合直接 UTF-8 字节写入完整日志记录

同样通过统一的 `host-process` 包装返回。

## 安全细节

`delete-directory-tree` 会拒绝删除不安全目录，例如 `/`。真正删除使用系统 `rm -rf`，但前面有 validate 保护。

`escape-sh-token` 使用单引号 quoting，并正确处理内部单引号：

```sh
'abc'\''def'
```

## 修改指南

修改 host 层时要非常谨慎：

1. 不要引入 TAFFISH 业务逻辑。
2. 验证受影响的后端及两个正式构建环境。
3. process 返回值语义必须保持。
4. 删除目录的安全校验不能削弱。
5. shell escaping 的行为会影响整个 TAFFISH 的安全性。
6. 必须在两个 release host 上复查 delivered CLI stdin 与非 ASCII 诊断。
