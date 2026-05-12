# container emitter

`emitter/builtins/container.lisp` 实现容器标签，是 TAFFISH 可移植性的核心实现之一。它支持 Docker、Podman 和 Apptainer，并允许按上下文选择实际后端。

## 作用

container emitter 负责把 TAF block 包装成容器运行命令。它解决：

1. 后端选择。
2. 镜像存在性检查和拉取。
3. home 与 workdir 挂载。
4. 用户环境传递。
5. Docker/Podman 与 Apptainer 差异。
6. 单命令执行与 heredoc 执行。

## 标签格式

基本格式：

```taf
RUN
<container:ubuntu:22.04>
echo hello
```

更完整形式：

```text
<CONTAINERS:IMAGE$RUN-ARGS>
```

其中：

| 部分 | 说明 |
| --- | --- |
| `CONTAINERS` | `container`、`docker`、`podman`、`apptainer`，可用 `/` 组合。 |
| `IMAGE` | 容器镜像。不能为空。 |
| `$RUN-ARGS` | 可选，追加到后端运行参数中。 |

示例：

```taf
<docker/podman:ubuntu:22.04$--network host>
```

如果 tag 以单引号开头，会强制 heredoc quoted。

## 后端选择

`container` 会展开为 context 中的 `:backend-order`，默认：

```lisp
(:apptainer :podman :docker)
```

实际选择还会参考：

1. `:available-backends`
2. `:force-backend`
3. tag 中请求的 backend kinds

如果 `:force-backend` 设置了，并且 tag 允许 `:container`，则会优先使用强制后端。否则按可用后端和顺序选择。

## Docker 与 Podman

Docker 和 Podman 共享大部分逻辑：

1. 检查命令是否存在。
2. 检查镜像是否存在。
3. 不存在时执行 pull。
4. 生成 `docker run` 或 `podman run`。
5. 默认 `--rm -i`。
6. 设置工作目录。
7. 追加默认挂载、配置参数和 tag 参数。

默认挂载包括：

1. home。
2. workdir。
3. extra mounts。

默认环境变量包括：

1. `HOME`
2. `USER`

## Apptainer

Apptainer 逻辑更复杂，因为它需要处理 SIF 文件：

1. 在 `:apptainer-image-dir` 中查找 SIF。
2. 如果不存在，寻找可写目录。
3. 根据 `:apptainer-auto-pull-p` 决定是否 pull。
4. 根据 `:apptainer-pull-source` 生成 pull source。
5. 对 Docker/OCI 镜像转换时检查 `mksquashfs`。
6. 使用 `apptainer exec` 运行。

SIF 文件名由 image 字符串转换得到，会把 `/`、`:`、`@` 替换为 `_`。

## 单命令与 heredoc

container emitter 会尝试判断 block 是否只有一个简单命令。如果是，并且没有强制 heredoc，就把命令直接放在容器命令后面。

如果不是简单命令，则使用：

```sh
bash <<EOF
...
EOF
```

或者 quoted heredoc：

```sh
bash <<'EOF'
...
EOF
```

quoted heredoc 可以避免宿主 shell 提前展开变量。

## 调试 prelude

container emitter 会生成专门的调试注释，包括：

1. chosen backend。
2. requested backends。
3. backend order。
4. available backends。
5. force backend。
6. image。
7. final run args。
8. payload limit。
9. heredoc quoted 状态。

这对定位用户机器上的容器问题很重要。

## 修改指南

修改 container emitter 时必须同时考虑三类兼容：

1. Docker。
2. Podman。
3. Apptainer。

还要检查：

1. `input.lisp` 的默认 container config。
2. 系统配置层是否需要暴露新选项。
3. shell quoting 是否安全。
4. home/workdir 挂载是否会覆盖用户数据。
5. 中国用户镜像或网络环境是否需要额外 source rewrite 支持。

container emitter 是 TAFFISH 强度的重要展示点，但也是风险最高的 emitter。不要在这里加入和具体生物信息工具强绑定的逻辑。
