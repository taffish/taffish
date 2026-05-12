# input.lisp

`input.lisp` 负责把外部输入参数和运行上下文规范化为 `taffish-core` 可以消费的结构。

## 作用

TAF 程序本身描述“要做什么”，但真正运行时还需要外部世界的信息，例如用户是谁、工作目录在哪里、传入参数是什么、容器后端有哪些。

`input.lisp` 把这些外部信息整理成两类对象：

1. `han.args:args-input`
2. `taf-context`

## normalize-input-args

`normalize-input-args` 接收一个 list，例如：

```lisp
("command" "--name" "alice")
```

第一项被视为 command，后续项被视为 argv。函数内部调用：

```lisp
han.args:parse-args-input
```

如果输入不是 list，会抛普通 `error`。

## normalize-input-context

`normalize-input-context` 接收 alist 或 `nil`，输出 `taf-context`。

已知键包括：

| key | taf-context 字段 |
| --- | --- |
| `:user` | `user` |
| `:homedir` | `homedir` |
| `:workdir` | `workdir` |
| `:loaddir` | `loaddir` |
| `:argv` | `argv` |
| `:cmd` | `cmd` |
| `:cpus` | `cpus` |
| `:container` | `container` |

未知键会保存在 `taf-context-extras` 中，方便未来扩展。

## 默认容器配置

`%default-container-config` 定义 container emitter 使用的默认配置：

| key | 默认值或作用 |
| --- | --- |
| `:backend-order` | `(:apptainer :podman :docker)` |
| `:available-backends` | 当前可用后端，默认空。 |
| `:force-backend` | 强制后端，默认 `nil`。 |
| `:pass-user-env-p` | 是否传递 USER/HOME 等用户环境。 |
| `:mount-homedir-p` | 是否挂载 home。 |
| `:mount-workdir-p` | 是否挂载工作目录。 |
| `:container-home-mode` | 容器内 home 规则，默认 `:same-as-host`。 |
| `:extra-mounts` | 额外挂载。 |
| `:docker-heredoc-quoted-p` | Docker heredoc 是否 quoted。 |
| `:podman-heredoc-quoted-p` | Podman heredoc 是否 quoted。 |
| `:apptainer-heredoc-quoted-p` | Apptainer heredoc 是否 quoted。 |
| `:docker-run-args` | Docker 额外 run args。 |
| `:podman-run-args` | Podman 额外 run args。 |
| `:apptainer-exec-args` | Apptainer 额外 exec args。 |
| `:apptainer-image-dir` | SIF 搜索和缓存目录。 |
| `:apptainer-quiet-p` | 是否使用 quiet 模式。 |
| `:apptainer-auto-pull-p` | SIF 不存在时是否自动 pull。 |
| `:apptainer-pull-source` | 默认从 Docker 源转换。 |

用户传入的 `:container` alist 会覆盖默认配置。未知 container key 会被保留。

## 与 binder 的关系

input 层只负责规范化。binder 会把 `taf-context` 转换为内置参数绑定，例如 `*WORKDIR*`、`*CPUS*`、`*CONTAINER*`。

## 修改指南

修改 `input.lisp` 时应检查：

1. `binder.lisp` 是否依赖新增 context 字段。
2. `container.lisp` 是否依赖新增 container key。
3. 默认值是否适合没有配置文件的最小运行场景。
4. 是否需要在 system config 层暴露对应配置。

不要在 input 层做 CLI help、项目配置读取或 shell 生成。
