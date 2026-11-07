# project/build

`project/build.lisp` 负责生成可分发命令 wrapper，并可选构建容器镜像。

## 作用

build 是把项目目录变成可安装 artifact 的步骤。它输出：

1. target 下的命令文件。
2. target 下的源码 snapshot。
3. snapshot 内的私有 build manifest。
4. 可选容器镜像。
5. 对 flow 项目的 dependencies 同步。

flow 依赖同步与 `taf check` 和编译器使用同一套源码内联边界。引号内的结束标记和
参数默认值不会产生额外依赖。版本规范化和 `[dependencies]` 写回仍沿用既有规则，
见[项目检查](project-check.md)。

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
5. `.taf-build.json`，记录 artifact、source 与 wrapper 身份

生成的 wrapper 会引用这个 snapshot，而不是直接引用开发目录。

## 精确且幂等的 command 构建

command-wrapper build 会对 `taffish.toml`、`src/` 与 `docs/` 计算稳定的 SHA-256
身份，其中包括目录结构和二进制文件内容；wrapper 本身也有精确 digest。只有 wrapper、
snapshot、可执行权限和 `.taf-build.json` 全部匹配时，第二次构建才报告 `up-to-date`，
且不重写 wrapper 或 snapshot。

manifest 缺失或损坏、source 改变、产物缺失、snapshot 多出文件或目录，都会触发一次
精确重建。`help2.md`、`docs2/`、`src2/` 等异常残留没有特殊语义；重建后的 snapshot
严格匹配项目 source，因此这些残留会消失。

重建使用 target 同目录下的 staging 和 backup 路径。staging 产物在替换前完成完整
校验；替换失败时恢复最后一个有效 wrapper 与 snapshot。清理范围仅限同一 artifact 的
临时路径，不会触碰其他 app 或版本。

即使版本文本不含点号（例如 `492`），最终 wrapper 也会使用精确 pathname；安装后的
wrapper 不会继承 staging 或 backup 后缀。旧中断事务留下的残留只会在同一 artifact
边界内被清理或恢复。

这里的幂等性只适用于 command wrapper 与冻结 snapshot。显式 container image build
仍会正常调用 Docker 或 Podman。

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

## 返回数据

公开返回值继续保留 `:project`、`:command` 与 `:image`。command plist 保留原有路径、
名称和依赖字段，并增加 `:status`（`:rebuilt` 或 `:up-to-date`）、
`:source-sha256`、`:wrapper-sha256` 与 `:manifest-file`。

## 修改指南

修改 build 时要检查：

1. wrapper 输出是否仍和 install、which、history 兼容。
2. artifact 命名是否仍和 hub index 一致。
3. snapshot 是否包含运行所需全部文件。
4. flow dependency 同步是否和 `project-check` 规则一致。
5. 容器 image tag 是否仍和 `[package].version/release` 一致。
6. 重复 command build 是否仍保持零写入，替换失败时是否保留最后有效产物。

## 操作状态提示

慢操作会在 stderr 提示当前目标与阶段。TTY 更新、日志限频、目标计数的含义、
静默/JSON 行为及限制见[命令状态与进度](command-progress.md)。提示不改变校验、写操作、重试或退出码规则。
