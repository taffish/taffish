# project/new

`project/new.lisp` 实现 `project-new`，用于生成一个新的 taf-app 项目骨架。

## 作用

`taf new` 不只是创建目录。它会生成一个可检查、可构建、可发布的最小项目：

```text
<project>/
  taffish.toml
  src/main.taf
  docs/help.md
  README.md
  LICENSE
  .gitignore
  release.md
  target/.gitkeep
  docker/Dockerfile              可选
  .github/workflows/build-image.yml  可选
```

## 输入参数

`project-new` 使用 `han.args` 解析参数：

| 参数 | 默认 | 作用 |
| --- | --- | --- |
| `--tool` / `-t` | false | 创建 tool。 |
| `--flow` / `-f` | false | 创建 flow。 |
| `--version` / `-v` | `0.1.0` | 初始版本。 |
| `--release` / `-r` | `1` | 初始 release，必须为正整数。 |
| `--license` / `-l` | `Apache-2.0` | 许可证模板。 |
| `--repo` / `-g` | 默认 GitHub URL | repository URL。 |
| `--image` / `-i` | nil | 显式容器镜像。 |
| `--docker` / `-d` | false | 生成 Dockerfile，并默认生成 GHCR image。 |
| `--no-actions` | false | 不生成 GitHub Actions。 |

如果没有指定 tool 或 flow，默认创建 flow。

## taffish.toml 生成

`%make-taffish-toml-string` 生成核心元数据：

1. `[package]`
2. `[repository]`
3. `[command]`
4. `[runtime]`
5. `[container]` 可选
6. 容器化项目可选生成 `[smoke]`

tool 默认：

```toml
[runtime]
pipe = true
command_mode = true
```

flow 默认：

```toml
[runtime]
pipe = false
command_mode = false
```

## main.taf 生成

flow 默认生成：

```taf
<taffish>
echo '<flow>[name: version] Hello, World!'
```

tool 默认生成：

```taf
<taf-app:shell>
echo '<tool>[name: version] Hello, World!'
```

如果设置 image，则 tool 入口会变成 `taf-app:container:<image>`。

## Docker 与 Actions

如果 `--docker` 开启：

1. 生成 `docker/Dockerfile`。
2. image 默认派生为 `ghcr.io/taffish/<name>:<version>-r<release>`。
3. 默认生成 GitHub Actions 工作流，除非传入 `--no-actions`。

Actions 工作流会读取 `taffish.toml`，构建 amd64 和可选 arm64 镜像，并发布 manifest。

容器化项目还会生成默认 smoke 模板：

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["TODO"]
test = ["TODO --help"]
```

这个模板刻意使用 TODO 占位。`taf check` 会拒绝这些默认值，因此维护者必须先把它们替换成
更贴合具体工具的检查，项目才算满足 publish/index 前的有效状态。

## 许可证

当前只支持 Apache-2.0 模板。其它 license 会报错。

## 修改指南

修改 `project/new` 时应同步检查：

1. `project/check` 是否仍接受新骨架，但默认 smoke TODO 这类有意占位除外。
2. `project/build` 是否能构建新骨架。
3. `project/publish` 是否能发布新骨架。
4. hub index 生成逻辑是否需要适配新增字段。
5. 默认 Actions 是否和当前 GitHub/GHCR 策略一致。
