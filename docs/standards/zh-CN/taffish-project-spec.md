# TAFFISH 项目规范

本页定义 taf-app 项目的目录、`taffish.toml`、构建产物和发布约定。

## 规范状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| 项目根目录与 `taffish.toml` | Draft v0.1 稳定 | `taf` 项目命令依赖该约定定位项目。 |
| `[package]`、`[repository]`、`[command]`、`[runtime]` | Draft v0.1 稳定 | 是 `project-check/build/publish/install` 的共同基础。 |
| `[container]` | Draft v0.1 稳定 | image/tag 一致性已经由检查器保护。 |
| `[dependencies]` | Draft v0.1 半稳定 | flow 依赖同步已实现，复杂依赖解析仍需 hub 迁移验证。 |
| GitHub 发布流程 | 当前实现 | 当前 `taf publish` 面向 GitHub；Gitee 是镜像分发层。 |

## 项目根目录

TAFFISH 项目根目录由 `taffish.toml` 标识。项目命令会从当前目录向上查找 `taffish.toml`，找到后将其所在目录视为 project root。

典型项目结构：

```text
<project>/
  taffish.toml
  src/
    main.taf
  docs/
    help.md
  target/
  README.md
  LICENSE
  release.md
```

`docs/help.md` 是构建出的 command wrapper 提供 `-h`/`--help` 时读取的文件，因此当前规范要求它存在。

## 受限 TOML 子集

当前参考实现不是完整 TOML 解析器，只支持 `taffish.toml` 需要的受限子集：

1. section 行，例如 `[package]`。
2. `key = value`。
3. 双引号字符串。
4. 字符串数组，例如 `["1.0-r1", "1.1-r1"]`。
5. `true` 和 `false`。
6. 非负整数字面量。
7. 整行注释和空行。

当前不支持内联注释、表数组、嵌套表、浮点数和完整 TOML 类型系统。项目文件应保持简单、显式、可由 TAFFISH 自身解析。

## `[package]`

必需字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `name` | string | 非空；只能包含 ASCII 字母、数字、`-`、`_`；不能以 `-` 或 `.` 开头。 |
| `kind` | string | 必须是 `tool` 或 `flow`。 |
| `version` | string | 非空；不能包含空格或 tab。 |
| `release` | integer | 正整数。 |
| `main` | string | 相对项目根目录；必须指向 `.taf` 文件；不能逃出项目根。 |

可选字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `license` | string | 非空字符串。 |

`version` 与 `release` 共同形成版本标识：

```text
<version>-r<release>
```

发布 tag 采用：

```text
v<version>-r<release>
```

## `[repository]`

必需字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `url` | string | 当前必须是 GitHub 仓库 URL。 |

当前接受的 GitHub URL 形式：

1. `https://github.com/<owner>/<repo>`
2. `git@github.com:<owner>/<repo>`
3. `ssh://git@github.com/<owner>/<repo>`

Gitee 镜像属于 source rewrite 和生态分发层，不改变项目的 canonical repository URL。

## `[command]`

必需字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `name` | string | 必须以 `taf-` 开头。 |

构建产物 artifact 名称为：

```text
<command.name>-v<package.version>-r<package.release>
```

例如：

```text
taf-demo-v0.1.0-r1
```

## `[runtime]`

必需字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `pipe` | boolean | 表示该工具是否按管道工具方式设计。 |
| `command_mode` | boolean | 表示 taf-app 包装时是否启用命令模式。 |

`taf new --tool` 当前默认：

```toml
[runtime]
pipe = true
command_mode = true
```

`taf new --flow` 当前默认：

```toml
[runtime]
pipe = false
command_mode = false
```

## `[container]`

可选字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `image` | string | 容器镜像名；tag 必须等于 `<version>-r<release>`。 |
| `dockerfile` | string | 相对项目根目录；文件必须存在；不能逃出项目根。 |
| `build_platforms` | string | 逗号分隔的平台列表，例如 `linux/amd64,linux/arm64`。 |
| `platforms` | string | legacy 字段；等价于 `build_platforms`。 |

如果设置了 `image`，主 TAF 文件中必须存在静态 container tag，并且 tag 中的 image 必须与 `[container].image` 一致。

`[container].image` 的 tag 必须匹配：

```text
<package.version>-r<package.release>
```

例如：

```toml
[package]
version = "0.1.0"
release = 1

[container]
image = "ghcr.io/taffish/demo:0.1.0-r1"
```

## `[smoke]`

容器化项目必须声明 `[smoke]`。非容器项目可以省略。`taf check` 只验证该
section 的结构，不执行 smoke test。

字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| `backend` | string | 可选；`docker`、`podman` 或 `apptainer`；默认 `docker`。 |
| `timeout` | integer | 可选正整数，单位为秒；默认 `60`。 |
| `exist` | string array | 可选；应该存在于容器 `PATH` 中的可执行命令名。 |
| `test` | string array | 可选；应该以退出码 `0` 正常结束的 shell 命令。 |

`exist` 和 `test` 至少有一个非空。
脚手架生成的默认 `TODO` 占位无效，必须替换后项目才能通过 `taf check`。

示例：

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["sh"]
test = ["sh -c true"]
```

Smoke 元数据面向 Hub/index 自动化。最终 index builder 可以针对已发布镜像运行这些检查，
记录 digest/platform 元数据，并把未通过的版本排除在公开 index 之外。

## `[dependencies]`

`[dependencies]` 记录 flow 依赖的 taf command。

字段规则：

1. key 必须以 `taf-` 开头。
2. value 可以是字符串，也可以是字符串数组。
3. 空数组不合法。
4. 值通常是 `latest` 或 `<version>-r<release>`。

示例：

```toml
[dependencies]
taf-fastqc = "0.12.1-r1"
taf-samtools = ["1.20-r1", "latest"]
```

flow 中的 `[[taf:...]]` 依赖引用会在 `taf build` 时同步回 `[dependencies]`。如果主 TAF 文件引用了依赖但 TOML 未声明，`taf check` 应报错并提示运行 `taf build` 同步。

## 构建产物

`taf build` 当前可以生成 command wrapper 和可选容器镜像。

command wrapper 输出：

```text
target/
  <artifact-name>
  .<artifact-name>/
    taffish.toml
    src/
    docs/
```

wrapper 运行时：

1. 找到 snapshot 中的 main TAF。
2. 调用 `taffish` 编译为临时 shell。
3. 执行临时 shell。
4. 写入 history JSONL。
5. 支持 `--version`、`--compile`、`--help`。

## 发布约定

`taf publish` 当前面向 GitHub。默认是 dry-run，只有显式关闭 dry-run 后才执行 git/gh 操作。

发布 tag：

```text
v<version>-r<release>
```

发布前必须满足：

1. `project-check` 通过。
2. `LICENSE` 存在、非空且不是 placeholder。
3. 如果启用 release，项目根目录必须有 `release.md`。
4. `release.md` 第一行不能为空，不能含 `TODO`。
5. 当前 `latest` 发布必须高于远端最新 tag；pre 发布可以放宽该限制。

TAFFISH 不负责 GitHub 登录。用户应自行配置 SSH key、credential helper 或 `gh auth login`。
