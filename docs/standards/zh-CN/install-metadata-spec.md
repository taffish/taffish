# TAFFISH 安装元数据规范

本页定义 `taffish.install/v1`，即 app 安装后写入的 `install.json`。

## 规范状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| `install.json` 位置 | Draft v0.1 稳定 | `list`、`which`、`uninstall` 都依赖该布局。 |
| 核心字段 | Draft v0.1 稳定 | 删除或改名需要迁移策略。 |
| command alias 刷新 | Draft v0.1 稳定 | 多版本安装依赖该规则。 |
| source commit 精确复现 | Draft v0.1 半稳定 | index 提供 `source.commit` 时，install 会在构建前校验实际源码 commit。 |

## 文件位置

安装元数据位于：

```text
<home>/apps/<package-name>/<version-id>/install.json
```

其中：

```text
<home>/apps/<package-name>/<version-id>/source/
```

保存实际 clone 或 copy 的 taf-app 源码。

## schema

当前 schema：

```json
{
  "schema_version": "taffish.install/v1"
}
```

读取安装元数据时，消费端主要依赖字段存在性；未来应更严格检查 schema。

## 字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `schema_version` | string | 必须是 `taffish.install/v1`。 |
| `installed_at` | string | UTC 时间，形如 `YYYY-MM-DDTHH:MM:SSZ`。 |
| `scope` | string | `user` 或 `system`。 |
| `name` | string | package name。 |
| `version_id` | string | `<version>-r<release>`。 |
| `artifact_name` | string | versioned artifact command 名。 |
| `command_name` | string/null | unversioned command alias 名。 |
| `command_file` | string | build 后真实 command wrapper 路径。 |
| `launcher_file` | string | versioned launcher 路径。 |
| `command_launcher_file` | string/null | unversioned alias launcher 路径。 |
| `bin_dir` | string | launcher 所在目录。 |
| `install_root` | string | 安装根目录。 |
| `source_dir` | string | 源码目录。 |
| `repository_url` | string/null | canonical repository URL。 |
| `source_url` | string/null | index 中记录的 source URL。 |
| `resolved_source_url` | string/null | source rewrite 后的 URL。 |
| `source_ref` | string/null | clone/copy 时使用的 ref。 |
| `source_commit` | string/null | index 中记录的 commit。 |
| `source_commit_actual` | string/null | install 校验时观测到的实际 Git `HEAD` commit。 |
| `source_commit_verified` | boolean | 当 `source_commit` 存在、实际 commit 匹配且源码工作区干净时为 true。 |
| `origin_kind` | string/null | 安装来源类型，例如 `hub-index` 或 `local-project`。 |
| `origin` | string/null | 安装来源值；Hub 安装为 repository URL，本地项目安装为项目根目录。 |
| `origin_display` | string/null | 人类可读的来源展示，例如 `[local-project] /path/to/app`。 |

## source commit 校验

如果 index version record 包含 `source.commit`，`taf install` 必须在调用
`project-build` 之前校验 resolved source：

1. 先对 `source_url` 应用 source rewrite。
2. clone 或 copy 源码进入安装事务。
3. 读取 resolved source 的 Git `HEAD` commit。
4. 要求它与 `source_commit` 一致。
5. 要求被检查的源码工作区是干净的。
6. commit 不一致或工作区不干净时，中止安装。

这条规则允许 mirror 和 source rewrite 改变访问路径，但不改变 canonical index
身份：用户实际拿到的源码 commit 必须与 index 记录一致。如果 `source_commit`
缺失，则 install 回退到旧的 ref/tag 安装行为。

## launcher 契约

安装器写入两个层次的 launcher：

1. versioned launcher：`<artifact_name>`。
2. command alias launcher：`<command_name>`，当 command name 与 artifact name 不同才有意义。

launcher 是 POSIX shell 脚本，设置：

```sh
TAF_LAUNCHER_NAME=<launcher-name>
TAF_LAUNCHER_ARTIFACT=<artifact-name>
```

然后执行 build 产生的 `command_file`：

```sh
exec <command_file> "$@"
```

`TAF_LAUNCHER_NAME` 用于 wrapper 知道用户实际调用的命令名。`TAF_LAUNCHER_ARTIFACT` 用于保留精确版本 artifact。

## command alias 刷新

当同一 command 安装多个版本时，unversioned alias 应指向最新 version id。

刷新规则：

1. 扫描同一 home 下所有 install metadata。
2. 只考虑 command name 一致、bin dir 一致、且 `command_file` 存在的安装记录。
3. 按 version id 版本顺序选择最新版本。
4. 写入或更新 alias launcher。
5. 如果没有候选版本，删除 alias launcher。

## 卸载行为

`taf uninstall` 应根据 `install.json` 定位：

1. install root。
2. versioned launcher。
3. command alias launcher。
4. command file。

卸载时：

1. 删除 versioned launcher。
2. 如果 command alias launcher 由当前安装记录拥有，则删除或刷新。
3. 删除 install root。
4. 保留容器镜像和 image cache。

如果找不到匹配项且未指定 force，应报错。指定 force 时可以视为 skipped。

## 兼容性要求

安装元数据是本地持久化状态。未来新增字段是兼容变化；删除或重命名字段需要迁移策略。

至少以下字段应长期保持可读：

1. `name`
2. `version_id`
3. `artifact_name`
4. `command_name`
5. `command_file`
6. `launcher_file`
7. `command_launcher_file`
8. `bin_dir`
9. `install_root`
10. `source_dir`
11. `origin_kind`
12. `origin`
13. `origin_display`

这些字段直接影响 `taf list`、`taf which`、`taf uninstall` 和 alias 刷新。
