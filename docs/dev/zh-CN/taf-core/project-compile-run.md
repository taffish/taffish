# project/compile 与 project/run

`project/compile.lisp` 把项目 main TAF 编译为 shell。`project/run.lisp` 在临时目录中写出 shell 并执行。

## project-compile 的作用

`project-compile` 的职责是：

1. 定位项目根。
2. 调用 `project-check` 获取项目元数据。
3. 读取 main TAF。
4. 构造 `taffish-core` context。
5. 调用 `taffish.core:taffish-to-shell`。

它不执行 shell，只返回 shell 字符串。

## context 构造

`%make-project-core-context` 会收集：

| key | 来源 |
| --- | --- |
| `:user` | 当前系统用户。 |
| `:homedir` | home 目录，必要时 fallback 到 `/root` 或 `/home/<user>`。 |
| `:workdir` | 调用时 start-dir 的绝对目录。 |
| `:loaddir` | main TAF 所在目录。 |
| `:argv` | 用户传入 args。 |
| `:cmd` | `taffish.toml` 的 command name。 |
| `:cpus` | `getconf`、`nproc`、`sysctl` 探测，失败则 1。 |
| `:container` | 可用后端与可选强制后端。 |

可用容器后端通过查找 `apptainer`、`podman`、`docker` 得到。

在项目编译和运行路径中，强制 backend 的生效优先级是：

1. 显式 `:container-backend`，例如 `taf run --backend podman`。
2. `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`。
3. 不强制 backend，`<container:...>` 走正常后端选择。

强制 backend 只影响通用 `<container:...>` tag。显式 `<docker:...>`、`<podman:...>` 和 `<apptainer:...>` tag 仍保持显式含义。

project compile/run 还会转发本机 backend runtime args：

1. `TAFFISH_DOCKER_RUN_ARGS`
2. `TAFFISH_PODMAN_RUN_ARGS`
3. `TAFFISH_APPTAINER_RUN_ARGS`

这些参数会在生成 shell 中追加到 `.taf` tag run-args 之后。它们用于本机策略，
例如 GPU flag 或站点特定 runtime 选项，而不是 app 层面的科学语义。

## compile 选项

当前支持：

```lisp
:container-backend
```

可取 `apptainer`、`podman`、`docker` 或对应 keyword。它会进入 context 的 `:container :force-backend`。

## project-run 的作用

`project-run` 在运行时：

1. 调用 `project-compile`。
2. 创建临时目录。
3. 写入 `run.sh`。
4. chmod 可执行。
5. 执行 shell。
6. 清理临时目录。

返回：

```lisp
(:exit-code ... :stdout ... :stderr ...)
```

## 输入输出

`project-run` 支持：

| 参数 | 作用 |
| --- | --- |
| `:input` | 传给运行程序的 stdin。 |
| `:output` | stdout 去向，默认 `t`。 |
| `:error-output` | stderr 去向，默认 `t`。 |

## 修改指南

修改 compile/run 时要检查：

1. context 字段是否和 `taffish-core/input.lisp`、`binder.lisp` 一致。
2. 容器后端强制逻辑是否影响 container emitter。
3. 临时目录是否总能清理。
4. stdout/stderr 返回约定是否影响 CLI。
5. 不要在 compile 中执行 shell，也不要在 run 中重新解析项目元数据。
