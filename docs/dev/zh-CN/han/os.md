# han.os OS 工具

`han.os` 是建立在 `han.host` 之上的操作系统便利层。它提供文件读取、环境变量、可执行查找和 shell 命令运行。

## 作用

`han.host` 处理 Lisp 实现差异，`han.os` 提供上层更容易使用的接口。TAFFISH 代码通常优先使用 `han.os`，只有需要底层 process handle 时才用 `han.host`。

## IO

| API | 作用 |
| --- | --- |
| `keep-read` | 持续 read 到 EOF 或 limit。 |
| `keep-read-char` | 持续 read-char。 |
| `keep-read-line` | 持续 read-line。 |
| `load-lines` | 从 stream 或 path 读取行列表。 |
| `load-string` | 读取成字符串，行之间用 newline 连接。 |

`load-string` shadow 了 CL 自带 `load-string` 概念，因此 package 中显式 shadow。

## 环境与路径

| API | 作用 |
| --- | --- |
| `getenv-default` | 环境变量不存在时返回默认值。 |
| `require-env` | 环境变量不存在时报错。 |
| `current-user` | 从 `USER` 或 `LOGNAME` 获取用户。 |
| `current-directory` | 当前目录 namestring。 |
| `home-directory` | home 目录 namestring。 |
| `find-executable` | 从 PATH 和 fallback path 查找程序。 |

`find-executable` 当前只检查文件存在，不检查 executable permission bits。这一点在 doctor 文档中也应该记住。

## shell 与进程

| API | 作用 |
| --- | --- |
| `escape-sh-token` | 委托 `han.host` 做 POSIX shell token quoting。 |
| `run-program` | 同步运行外部命令，返回 stdout、stderr、exit-code。 |
| `run-shell-command` | 用 bash 或 sh 运行 shell command。 |

`run-shell-command` 在 wait 模式下会通过 `han.host:run-program-sync` 收集 stdout/stderr，避免大输出 pipe buffer deadlock。

如果 `lines t`，返回 stdout-lines、stderr-lines、exit-code；如果 `lines nil`，返回字符串。

## 修改指南

修改 `han.os` 时要检查：

1. `taf-core/project/compile.lisp` 的 CPU 和 backend 探测。
2. `taf-core/project/build.lisp` 的 chmod 和 build 命令。
3. `taf-core/hub/update.lisp` 的 curl 下载。
4. `taf-core/system/doctor.lisp` 的 executable 检查。
5. `run-shell-command` 的返回值形状不要轻易改变。
