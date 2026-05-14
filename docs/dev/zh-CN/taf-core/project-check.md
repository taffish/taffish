# project/check

`project/check.lisp` 是 TAFFISH 项目契约的中心。它读取 `taffish.toml`，检查项目文件和主 TAF，并返回标准 project plist。

## 作用

`project-check` 的职责是把“一个目录看起来像 taf-app”升级为“一个结构经过验证的 taf-app 项目”。

很多上层命令依赖它：

1. `project-compile`
2. `project-build`
3. `project-run`
4. `project-publish`
5. `hub-install` 中的源码构建

## TOML 子集

当前实现包含一个小型 TOML parser，支持 TAFFISH 需要的子集：

1. section。
2. key/value。
3. quoted string。
4. string array。
5. boolean。
6. 非负数字形式的 integer。

它不是完整 TOML 实现。维护时不要把它当成通用 TOML parser。

## 必需 section 和字段

`project-check` 会读取：

| section | 字段 | 要求 |
| --- | --- | --- |
| `[package]` | `name` | 非空，符合项目命名规则。 |
| `[package]` | `kind` | `tool` 或 `flow`。 |
| `[package]` | `version` | 非空且不含空白。 |
| `[package]` | `release` | 正整数。 |
| `[package]` | `main` | 项目相对路径，必须是 `.taf`。 |
| `[repository]` | `url` | GitHub repository URL。 |
| `[command]` | `name` | 必须以 `taf-` 开头。 |
| `[runtime]` | `pipe` | boolean。 |
| `[runtime]` | `command_mode` | boolean。 |

可选字段包括 license、container image、dockerfile、build platforms、smoke 元数据、
dependencies，以及 `[meta]`、`[upstream]` 这类生态元数据。

## 可选生态元数据

`project-check` 当前保持 `[meta]` 和 `[upstream]` 可选。它不要求这些 section
存在，也不会因为缺少它们而让本地项目报错。如果这些 section 存在，它们仍然需要
使用受限 TOML 子集。

对于 `[upstream]`，`project-check` 同时接受 `repository` 和兼容别名 `repo`。
两者都会被规范化为返回 project plist 中的 `:upstream :repository`。如果两个字段
同时存在，它们必须一致。

这个边界是刻意的：

1. 本地私有 app 和实验项目应该保持轻量。
2. 公开 Hub/index producer 可以施加更严格的收录规则。
3. 官方生态元数据要求应可以演进，但不破坏旧的本地项目。

## 主 TAF 检查

`%check-taf-main-file` 会确认 main 文件存在，并调用：

```lisp
taffish.core:parse-taf
```

这意味着 `taf check` 会做 TAF 静态语法检查，但不会绑定真实参数或执行。

## flow 依赖检查

对于 flow 项目，`project-check` 会扫描 `<taffish>` block 中的：

```text
[[taf: ...]]
```

并要求 `taffish.toml` 的 `[dependencies]` 声明这些依赖。

如果 inline 依赖是精确 artifact 名，例如带 `-v...-r...` 的形式，则 dependencies 必须包含对应版本。否则可以使用已有声明或 `latest` 语义。

缺失依赖时，错误信息会提示运行 `taf build` 同步。

## container image 检查

如果 `[container].image` 存在，`project-check` 会检查：

1. image tag 必须等于 `<version>-r<release>`。
2. main TAF 中必须有静态 container tag 使用该 image。
3. main TAF 中静态 container image 必须和 `taffish.toml` 一致。

这保证项目元数据、容器镜像和 TAF 入口不会相互漂移。

## smoke 元数据检查

如果项目声明了 `[container].image` 或 `[container].dockerfile`，`project-check`
会要求存在 `[smoke]`，并检查：

1. `backend` 若存在，必须是 `docker`、`podman` 或 `apptainer`。
2. `timeout` 若存在，必须是正整数。
3. `exist` 和 `test` 若存在，必须是字符串数组。
4. `exist` 和 `test` 至少有一个非空。

这个检查是声明式的，不运行容器。真正的 smoke 执行属于 Hub/index 自动化，
因为那里可以测试最终发布的镜像，并记录 digest/platform 元数据。

## 输出 project plist

`project-check` 返回 plist，重要字段包括：

| 字段 | 含义 |
| --- | --- |
| `:root-dir` | 项目根目录。 |
| `:toml-file` | `taffish.toml` 路径。 |
| `:name` | package name。 |
| `:kind` | `:tool` 或 `:flow`。 |
| `:version` | package version。 |
| `:release` | release integer。 |
| `:repository-url` | GitHub repository。 |
| `:command-name` | 逻辑命令名。 |
| `:main-path` | main 相对路径。 |
| `:main-file` | main 绝对路径。 |
| `:help-file` | `docs/help.md`。 |
| `:target-dir` | target 目录。 |
| `:runtime-pipe` | runtime pipe。 |
| `:runtime-command-mode` | runtime command mode。 |
| `:container-image` | image。 |
| `:dependencies` | 规范化依赖。 |
| `:smoke` | 规范化 smoke 元数据 plist 或 nil。 |
| `:dockerfile` | Dockerfile 相对路径。 |
| `:container-build-platforms` | build platforms。 |

## 修改指南

修改 `project-check` 时要非常谨慎，因为它定义项目标准：

1. 新增 `taffish.toml` 字段时，要决定是否必需、是否兼容旧项目。
2. 改变 dependencies 规则时，要同步 `project-build` 的自动同步逻辑。
3. 改变 container image 规则时，要同步 `taf new` 和 hub index。
4. 错误信息应给出用户可执行的修复方向。
