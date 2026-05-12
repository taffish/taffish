# han.os OS Tools

`han.os` is the operating-system convenience layer built on top of `han.host`. It provides file reading, environment variables, executable lookup, and shell command execution.

## Role

`han.host` handles Lisp implementation differences, while `han.os` provides easier interfaces for upper layers. TAFFISH code usually prefers `han.os`; use `han.host` only when a low-level process handle is needed.

## IO

| API | Role |
| --- | --- |
| `keep-read` | Keep reading until EOF or limit. |
| `keep-read-char` | Keep reading characters. |
| `keep-read-line` | Keep reading lines. |
| `load-lines` | Read a list of lines from a stream or path. |
| `load-string` | Read as a string, joining lines with newlines. |

`load-string` shadows the CL concept of `load-string`, so the package explicitly shadows it.

## Environment And Paths

| API | Role |
| --- | --- |
| `getenv-default` | Return default when an environment variable is missing. |
| `require-env` | Error when an environment variable is missing. |
| `current-user` | Get user from `USER` or `LOGNAME`. |
| `current-directory` | Current directory namestring. |
| `home-directory` | Home directory namestring. |
| `find-executable` | Find a program from PATH and fallback path. |

`find-executable` currently checks only file existence, not executable permission bits. This should also be remembered in doctor docs.

## Shell And Process

| API | Role |
| --- | --- |
| `escape-sh-token` | Delegate POSIX shell token quoting to `han.host`. |
| `run-program` | Run an external command synchronously and return stdout, stderr, exit-code. |
| `run-shell-command` | Run a shell command using bash or sh. |

In wait mode, `run-shell-command` collects stdout/stderr through `han.host:run-program-sync`, avoiding pipe buffer deadlock on large output.

If `lines t`, it returns stdout-lines, stderr-lines, exit-code. If `lines nil`, it returns strings.

## Modification Guide

When changing `han.os`, check:

1. CPU and backend detection in `taf-core/project/compile.lisp`.
2. chmod and build commands in `taf-core/project/build.lisp`.
3. curl download in `taf-core/hub/update.lisp`.
4. executable checks in `taf-core/system/doctor.lisp`.
5. Do not change the return shape of `run-shell-command` casually.

