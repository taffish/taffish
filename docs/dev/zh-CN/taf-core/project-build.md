# project/build

`project/build.lisp` 负责生成可分发命令 wrapper，并可选构建容器镜像。

## 作用

build 是把项目目录变成可安装 artifact 的步骤。它输出：

1. target 下的命令文件。
2. target 下的源码 snapshot。
3. 可选容器镜像。
4. 对 flow 项目的 dependencies 同步。

## artifact 命名

artifact 名称为：

```text
<command-name>-v<version>-r<release>
```

例如：

```text
taf-example-v0.1.0-r1
```

这也是 hub install 时校验 built artifact 是否匹配 index 的关键。

## source snapshot

`%snapshot-project-source` 会把项目必要内容复制到：

```text
target/.<artifact-name>/
```

包含：

1. `taffish.toml`
2. `src/`
3. `docs/`
4. main TAF 文件

生成的 wrapper 会引用这个 snapshot，而不是直接引用开发目录。

## wrapper 行为

build wrapper 是一个 shell 脚本，支持：

| 参数 | 行为 |
| --- | --- |
| `--` | 之后参数传给 TAF。 |
| `-v` / `--version` | 输出 package、version、kind、repository。 |
| `--compile` | 调用 `taffish` 输出生成 shell。 |
| `-h` / `--help` | 输出 snapshot 中的 `docs/help.md`。 |
| 默认 | 编译 TAF 到临时 shell，再执行。 |

wrapper 会记录运行历史到 JSONL，默认异步写入。可通过环境变量控制：

| 变量 | 作用 |
| --- | --- |
| `TAFFISH` | 指定 taffish 编译器路径。 |
| `TAF_HISTORY_MODE` | `async`、`sync`、`off`。 |
| `TAF_HISTORY_FILE` | 指定 history 文件。 |
| `TAFFISH_USER_HOME` | 默认 history home。 |

## flow dependency 同步

对于 flow 项目，`%build-sync-flow-dependencies` 会扫描 main TAF 的 `[[taf: ...]]` 引用，并重写 `taffish.toml` 的 `[dependencies]` section。

这使 flow 的实际组合依赖和项目元数据保持一致。

## 容器镜像构建

如果 `project-build` 传入 `:image-p t`，会使用 Docker 或 Podman 构建 image。

后端选择：

1. 显式 `backend`。
2. 系统中可用的 Docker。
3. 系统中可用的 Podman。

构建命令大致是：

```sh
docker build -t <image> -f <dockerfile> <root>
```

## 修改指南

修改 build 时要检查：

1. wrapper 输出是否仍和 install、which、history 兼容。
2. artifact 命名是否仍和 hub index 一致。
3. snapshot 是否包含运行所需全部文件。
4. flow dependency 同步是否和 `project-check` 规则一致。
5. 容器 image tag 是否仍和 `[package].version/release` 一致。
