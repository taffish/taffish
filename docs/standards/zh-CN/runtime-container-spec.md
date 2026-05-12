# TAFFISH 运行时与容器规范

本页定义 TAFFISH 运行时上下文、生成 shell 和容器后端的主要契约。

## 规范状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| context 已知字段 | Draft v0.1 稳定 | 编译和内置参数依赖这些字段。 |
| Docker/Podman/Apptainer 后端选择 | Draft v0.1 稳定 | 当前容器可移植性的核心规则。 |
| 默认挂载与 HOME/USER 传递 | Draft v0.1 半稳定 | 已可用，但高级 HPC 场景可能需要扩展。 |
| SIF 缓存与 auto pull | Draft v0.1 半稳定 | 已实现，后续可能加入锁、metadata 和清理策略。 |
| 高级后端参数 | Experimental | 可通过配置传入，但不建议生态依赖具体细节。 |

## 运行时上下文

`taffish-core` 编译时接收 context alist，并规范化为 `taf-context`。

已知字段：

| 字段 | 说明 |
| --- | --- |
| `:user` | 主机用户名。 |
| `:homedir` | 主机 home 目录。 |
| `:workdir` | 主机工作目录。 |
| `:loaddir` | TAF 文件加载目录。 |
| `:argv` | 原始 argv。 |
| `:cmd` | command 名称。 |
| `:cpus` | 可用 CPU 数。 |
| `:container` | 容器配置 alist。 |

未知字段应保存在 `taf-context-extras` 中，供未来扩展。

## 默认容器配置

默认容器配置：

```lisp
((:backend-order . (:apptainer :podman :docker))
 (:available-backends . ())
 (:force-backend . nil)
 (:pass-user-env-p . t)
 (:mount-homedir-p . t)
 (:mount-workdir-p . t)
 (:container-home-mode . :same-as-host)
 (:extra-mounts . nil)
 (:docker-heredoc-quoted-p . nil)
 (:podman-heredoc-quoted-p . nil)
 (:apptainer-heredoc-quoted-p . nil)
 (:docker-run-args . nil)
 (:podman-run-args . nil)
 (:apptainer-exec-args . nil)
 (:apptainer-image-dir . ("${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif"
                          "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif"))
 (:apptainer-quiet-p . t)
 (:apptainer-auto-pull-p . t)
 (:apptainer-pull-source . :docker))
```

调用方可以覆盖这些 key。未知 container key 当前会保留在配置 alist 中，但内置 emitter 不应依赖未知 key。

## container tag 语法

容器子标签形如：

```taf
<CONTAINERS:IMAGE>
<CONTAINERS:IMAGE$RUN-ARGS>
<'CONTAINERS:IMAGE>
```

`CONTAINERS` 可以是：

1. `container`
2. `docker`
3. `podman`
4. `apptainer`
5. 用 `/` 连接的候选列表，例如 `docker/podman`

`container` 是虚拟后端，按 `:backend-order` 展开。

`IMAGE` 不能为空。`$RUN-ARGS` 是直接追加给后端运行命令的额外参数字符串。

如果 tag 内容以单引号开头，例如：

```taf
<'docker:ghcr.io/taffish/demo:0.1.0-r1>
```

表示强制使用 heredoc 形式，并对 heredoc delimiter 使用 quoted 模式。

## 后端选择

后端选择流程：

1. 如果 tag 明确指定 `docker`、`podman` 或 `apptainer`，只从这些候选中选择。
2. 如果 tag 使用 `container`，按 `:backend-order` 展开。
3. `:force-backend` 只在候选包含 `:container` 时强制生效。
4. 最终后端必须存在于 `:available-backends` 中。
5. 找不到可用后端时，应报错。

`taf compile` 和项目编译层会根据本机可执行程序检测 `:available-backends`，顺序包括 Apptainer、Podman、Docker。

运行时调用方可以通过设置 `:container :force-backend` 强制通用 `<container:...>` tag 的后端。在 CLI/project 层，来源优先级是：

1. 显式命令选项，例如 `taf run --backend podman`。
2. `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`。
3. 不强制 backend。

这条强制规则不会覆盖显式 backend tag，例如 `<docker:...>`、`<podman:...>` 或 `<apptainer:...>`。

## Docker/Podman 运行契约

Docker 和 Podman 使用共享逻辑：

1. 检查后端命令是否存在。
2. 检查 image 是否已存在。
3. 如不存在，执行 pull。
4. 使用 `run --rm -i`。
5. 设置 workdir。
6. 挂载 home、workdir 和 extra mounts。
7. 按配置传递 HOME 和 USER。
8. 单行简单命令可以直接作为 command 传入。
9. 多行或复杂命令使用 heredoc。

默认挂载：

| 配置 | 行为 |
| --- | --- |
| `:mount-homedir-p` | 将 host homedir 挂载到 container home。 |
| `:mount-workdir-p` | 将 host workdir 挂载到同一路径。 |
| `:extra-mounts` | 逐项添加 `-v` 挂载。 |

Docker/Podman 额外参数：

| 后端 | 配置 key |
| --- | --- |
| Docker | `:docker-run-args` |
| Podman | `:podman-run-args` |

## Apptainer 运行契约

Apptainer 运行流程：

1. 检查 `apptainer` 是否存在。
2. 根据 image 生成 SIF 文件名。
3. 在 `:apptainer-image-dir` 中查找已有 SIF。
4. 如果找不到，选择可写目录作为 SIF 目标。
5. 如果允许 auto pull，则执行 `apptainer pull`。
6. 如果从 Docker/OCI 源 pull，要求 `mksquashfs` 可用。
7. 使用 `apptainer exec --pwd <workdir>` 运行。

SIF 文件名由 image 字符串转换：

```text
[/:@] -> _
```

并追加 `.sif`。

Apptainer pull source：

| 配置值 | pull ref |
| --- | --- |
| `:docker` | `docker://<image>` |
| `:oras` | `oras://<image>` |
| `:library` | `library://<image>` |

默认值是 `:docker`。

## container home

`container-home-mode` 当前支持：

| 值 | 行为 |
| --- | --- |
| `:same-as-host` 或 `nil` | container home 与 host homedir 相同。 |
| `:linux-user-home` | `/home/<user>`，无 user 时为 `/home/user`。 |

workdir 选择：

1. 如果 `:mount-workdir-p` 且有 host workdir，使用 host workdir。
2. 否则如果有 container home，使用 container home。
3. 否则使用 `/work`。

## heredoc 与单命令

container emitter 会判断 block 是否只有一条简单命令。简单命令不能包含以下 shell 控制字符：

```text
; & | < > `
```

并且不能包含 `$(`。

简单命令可以直接作为后端 command；否则使用：

```sh
bash <<EOF
...
EOF
```

quoted heredoc 使用：

```sh
bash <<'EOF'
...
EOF
```

## 生成 shell 的可调试性

容器 emitter 应输出调试 prelude，包括：

1. chosen backend。
2. requested backends。
3. backend order。
4. available backends。
5. force backend。
6. image。
7. final run args。
8. payload mode。
9. heredoc quoted 状态。

这些注释是生成 shell 可读性的一部分，不应轻易删除。
