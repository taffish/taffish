# TAFFISH 合规性检查清单

本页用于人工检查一个 `.taf` 文件、taf-app 项目、hub index 或本地安装结果是否符合 TAFFISH Specification Draft v0.1。它不是自动测试，但应该作为未来一致性测试的蓝本。

## 结果分类

| 结果 | 含义 |
| --- | --- |
| 合格 | 满足所有必须项，没有明显依赖未稳定行为。 |
| 警告 | 满足必须项，但依赖 legacy 字段、当前实现细节或未稳定行为。 |
| 失败 | 违反必须项，可能导致解析、构建、安装、运行或卸载失败。 |

检查时建议记录：

```text
target:
scope:
result: 合格/警告/失败
checked_at:
notes:
```

## `.taf` 文件检查

### 必须项

- 文件不是空文件。
- 主结构至多包含一个 `ARGS` block 和一个 `RUN` block。
- 如果存在 `ARGS`，它必须位于 `RUN` 之前。
- `RUN` block 必须存在，或文件必须能通过规范化生成 `RUN` block。
- 每个非空运行子标签必须有内容。
- `ARGS` 子标签头不能包含 `::...::` 参数 token。
- 所有 `::...::` 参数 token 必须闭合。
- 未声明且无默认值的普通参数不能在代码中使用。
- 内置参数只能使用保留名称，例如 `*USER*`、`*HOMEDIR*`、`*WORKDIR*`。
- 子标签必须能被某个 emitter 识别，或明确属于实验扩展。

### 应该项

- 复杂文件应该显式写出 `RUN`，而不是依赖裸代码规范化。
- 复杂工具应该显式写出 `ARGS`，使参数入口可读。
- 参数 token 周围的 shell quoting 应清晰可审查。
- 容器 tag 中的 image 应使用明确 tag，而不是隐式 latest。
- flow 中的 `[[taf:...]]` 依赖引用应能同步到 `[dependencies]`。

### 警告项

- 使用 `<taffish>` 内联组合语法。
- 使用 `taf-app` 命令模式。
- 子标签头中包含动态参数 token。
- 容器 tag 使用 `$RUN-ARGS` 传入复杂 shell 片段。

## taf-app 项目检查

### 必须项

- 项目根目录存在 `taffish.toml`。
- `[package].name` 非空，只包含 ASCII 字母、数字、`-`、`_`，且不以 `-` 或 `.` 开头。
- `[package].kind` 是 `tool` 或 `flow`。
- `[package].version` 非空，且不包含空格或 tab。
- `[package].release` 是正整数。
- `[package].main` 是项目内相对路径，指向 `.taf` 文件。
- `[repository].url` 是 canonical GitHub 仓库 URL。
- `[command].name` 以 `taf-` 开头。
- `[runtime].pipe` 和 `[runtime].command_mode` 是布尔值。
- `docs/help.md` 存在。
- 主 `.taf` 文件可以被解析。
- 如果存在 `[container].dockerfile`，路径必须在项目内且文件存在。
- 如果存在 `[container].image`，image tag 必须等于 `<version>-r<release>`。
- 如果存在 `[container].image`，主 `.taf` 文件中的静态容器 image 必须与它一致。
- 如果存在 `[container].image` 或 `[container].dockerfile`，必须存在合法 `[smoke]`。
- `[smoke].backend` 若存在，只能是 `docker`、`podman` 或 `apptainer`。
- `[smoke].timeout` 若存在，必须是正整数。
- `[smoke].exist` 和 `[smoke].test` 若存在，必须是字符串数组，且至少一个非空。
- `[smoke].exist` 和 `[smoke].test` 不包含默认 `TODO` 占位。
- 如果是 flow，主 `.taf` 中的 `[[taf:...]]` 依赖必须在 `[dependencies]` 中声明或可由 `taf build` 同步。

### 应该项

- `README.md` 应说明 app 的用途。
- `LICENSE` 应存在且不是 placeholder。
- `release.md` 在发布前应存在，第一行是清楚的发布摘要。
- tool 项目通常应设置 `pipe = true` 和 `command_mode = true`。
- flow 项目通常应设置 `pipe = false` 和 `command_mode = false`。
- 容器化工具应同时给出 Dockerfile 和明确 image。
- `[dependencies]` 中应尽量使用精确 version id，而不是长期依赖 `latest`。
- 准备公开 Hub 收录的 app 应添加 `[meta]`，包含 domain、category、summary 和 keywords。
- 包装第三方软件的 tool app 应尽量添加 `[upstream]`，包含上游 name、version、URL、开源协议/许可证和 citation。

### 警告项

- 使用 legacy `[container].platforms`。
- `[dependencies]` 使用 `latest` 或 `*`。
- repository URL 与实际镜像来源混用。
- 公开 Hub 候选 app 缺少 `[meta]`，或第三方 tool wrapper 缺少 `[upstream]`。
- `release.md` 仍保留默认发布占位符，或 README 中仍包含未完成的 TODO 类占位内容。

## hub index 检查

### 必须项

- 顶层是 JSON object。
- `schema_version` 等于 `taffish.index/v1`。
- 顶层存在 object 字段 `packages`。
- 顶层存在 object 字段 `commands`。
- 每个 package entry 是 object。
- 每个 package entry 的 `versions` 是 object。
- 每个 package entry 的 `latest` 指向存在的 version id。
- 每个用于安装的 version record 包含 `version` 和 `release`。
- 每个用于安装的 version record 包含 `command.name`。
- 每个用于安装的 version record 能解析出 source URL。
- 每个 command entry 的 `package` 指向存在的 package。
- exact artifact 名称符合 `<command>-v<version>-r<release>`。

### 应该项

- version record 应包含 `version_id`，且等于 `<version>-r<release>`。
- version record 应包含 `tag`，且等于 `v<version-id>`。
- version record 应包含 `kind`、`license`、`repository_url`、`repository_slug`。
- `source` 应包含 canonical GitHub URL 和 ref。
- release tag record 应把被索引的 Git commit 写入 `source.commit`。
- `container.image_tag` 应等于 version id。
- 如果存在容器，version record 应记录 `smoke` 元数据、镜像 digest 和支持平台。
- `runtime.pipe` 和 `runtime.command_mode` 应来自项目 TOML。
- package entry 与 version record 中的 command 信息应一致。

### 警告项

- source 只给出 `local_path`，除非这是开发或测试 index。
- dependency value 使用 `latest`、`*` 或 `null`。
- package `latest` 不是语义上最新的 version id。
- index 同时混入 canonical GitHub URL 和镜像 URL。

## install metadata 检查

### 必须项

- 文件位于 `<home>/apps/<package-name>/<version-id>/install.json`。
- `schema_version` 等于 `taffish.install/v1`。
- `name`、`version_id`、`artifact_name` 非空。
- `command_name` 非空或为 null。
- `command_file`、`launcher_file`、`bin_dir`、`install_root`、`source_dir` 非空。
- `launcher_file` 存在。
- `install_root` 存在。
- `source_dir` 存在。
- versioned launcher 执行目标是 `command_file`。
- 如果存在 command alias，它必须指向当前 command 的最新已安装版本。

### 应该项

- `installed_at` 使用 UTC `YYYY-MM-DDTHH:MM:SSZ`。
- `repository_url` 保持 canonical GitHub URL。
- `resolved_source_url` 记录 source rewrite 后的实际来源。
- `source_ref` 与 index record 一致。
- `source_commit` 尽可能记录。
- 如果存在 `source_commit`，`source_commit_actual` 应与其一致，且 `source_commit_verified` 为 true。

### 警告项

- `command_file` 不存在，但 metadata 仍存在。
- `command_launcher_file` 存在但不包含当前 command file。
- `source_commit` 缺失，导致复现只能依赖 tag 或 branch。
- `source_commit` 存在但未 verified，导致安装源码路径不能完整审计。

## config/home 检查

### 必须项

- `config.toml` 如果存在，schema 必须是 `taffish.config/v1`。
- config 中不能出现未知 section。
- `[index].url` 如果存在，必须是非空字符串。
- `[[source.rewrite]]` 的 `from` 和 `to` 必须是非空字符串。
- `[[source.rewrite]].enabled` 如果存在，必须是布尔值。
- active home 必须能解析为 user 或 system scope。
- 安装或 update 前，active home 应具备必需目录，或能通过 `taf doctor --init` 创建。

### 应该项

- 中国镜像应通过 source rewrite 实现，而不是把 canonical index 记录改成镜像身份。
- GitHub canonical 组织应为 `taffish`。
- Gitee 镜像组织应为 `taffish-org`。
- user scope 的 command bin 应在 PATH 中。

### 警告项

- `TAFFISH_CONFIG` 指向的文件覆盖了 source rewrite 但没有记录原因。
- system scope 在非 root 环境下初始化。
- command bin 不在 PATH 中。

## runtime/container 检查

### 必须项

- container tag 中的 image 非空。
- 请求的后端必须是 `container`、`docker`、`podman`、`apptainer` 或其 `/` 组合。
- 实际选择的后端必须在 available backends 中。
- `force-backend` 如果设置，必须是 `apptainer`、`podman` 或 `docker`。
- Docker/Podman/Apptainer 命令缺失时，生成 shell 必须报错退出。
- Apptainer auto pull 从 Docker/OCI 源转换 SIF 时，缺少 `mksquashfs` 必须报错。

### 应该项

- 默认后端顺序应优先 Apptainer，再 Podman，再 Docker。
- 生成 shell 应保留容器调试 prelude。
- 容器运行应挂载 home 和 workdir，除非配置明确关闭。
- 不应直接拼接未转义用户输入到 shell 命令中。
- 镜像 tag 应与 taf-app version id 对齐。

### 警告项

- 使用复杂 `$RUN-ARGS`。
- 关闭 home/workdir 挂载。
- 依赖 Apptainer 自动拉取远程镜像，但没有预先缓存 SIF。
- 在 HPC 场景中依赖 Docker-only 行为。

## history 检查

### 必须项

- history 文件使用 JSON Lines。
- 每行应是独立 JSON object。
- 写入失败不应改变主命令退出码。
- wrapper 记录 `exec` event 时应包含 `status` 和 `exit_code`。

### 应该项

- 记录 `id`、`time`、`command`、`args`、`cwd`。
- 项目命令应记录 project name、version、release、repository 和 container image。
- 时间应为 UTC。

### 警告项

- history 中缺少 `source_commit` 或 snapshot 信息，导致审计能力不足。
- `TAF_HISTORY_MODE=off` 用于正式复现实验但没有额外 provenance 记录。

## 发布前总检查

发布 taf-app 前，至少应通过：

1. `.taf` 文件检查。
2. taf-app 项目检查。
3. 如果有容器，runtime/container 检查。
4. 如果要进入 hub，hub index 记录检查。
5. 如果要验证安装，install metadata 检查。

发布 TAFFISH 自身或 taffish-hub 前，至少应通过：

1. schema 版本检查。
2. 兼容性策略检查。
3. source rewrite 检查。
4. 旧安装记录读取检查。
5. 关键 example app 的安装、运行和卸载检查。

## 从 checklist 到自动一致性测试

未来可以把本页拆成自动测试：

1. `taf conformance taf <file>`：检查单个 `.taf`。
2. `taf conformance project <dir>`：检查 taf-app 项目。
3. `taf conformance index <index.json>`：检查 hub index。
4. `taf conformance install <home>`：检查本地安装状态。

在自动化实现之前，本页就是人工迁移 taffish-hub 和审核 taf-app 的准绳。
