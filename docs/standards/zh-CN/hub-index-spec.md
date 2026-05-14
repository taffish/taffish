# TAFFISH Hub Index 规范

本页定义 `taffish.index/v1` 的消费侧规范。index 的生产流程可以由 taffish-hub 或其他工具实现，但输出必须满足本页契约。

## 规范状态

| 范围 | 状态 | 说明 |
| --- | --- | --- |
| `schema_version`、`packages`、`commands` | Draft v0.1 稳定 | 消费端命令已经依赖这些字段。 |
| package entry 与 version record | Draft v0.1 待生态验证 | 字段结构已明确，但需要 taffish-hub 迁移验证生产端。 |
| dependencies | Draft v0.1 半稳定 | 安装器支持递归安装和循环检测，但复杂生态还未充分验证。 |
| 多源镜像 | 当前实现 | 通过 config source rewrite 实现，不属于 index schema 的直接职责。 |

## 文件格式

hub index 是 JSON object，顶层必须包含：

```json
{
  "schema_version": "taffish.index/v1",
  "packages": {},
  "commands": {}
}
```

`taf update` 对下载内容只做轻量检查，但 `taf info/search/list/install` 会解析 JSON 并检查 schema。

## 顶层字段

| 字段 | 类型 | 必需 | 说明 |
| --- | --- | --- | --- |
| `schema_version` | string | 是 | 必须是 `taffish.index/v1`。 |
| `packages` | object | 是 | package name 到 package entry 的映射。 |
| `commands` | object | 是 | command name 到 command entry 的映射。 |

可以添加额外顶层字段，但消费端不能依赖未规范字段。

## package entry

`packages` 的 key 是 package name。value 应是 object。

核心字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | string | package 显示名，可与 key 一致。 |
| `latest` | string | 默认 version id。 |
| `repository_url` | string | canonical repository URL。 |
| `command` | object | package 默认 command 信息。 |
| `versions` | object | version id 到 version record 的映射。 |

`latest` 应指向 `versions` 中存在的 key。

## command entry

`commands` 用于从命令名反查 package。

典型结构：

```json
{
  "taf-demo": {
    "package": "demo",
    "version": "0.1.0-r1"
  }
}
```

字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `package` | string | 指向 `packages` 中的 package key。 |
| `version` | string | 默认 version id，可省略时由 package latest 决定。 |

## version id

version id 当前采用：

```text
<version>-r<release>
```

用户输入 version id 时，前导 `v` 会被规范化去掉。因此 `v0.1.0-r1` 和 `0.1.0-r1` 可以解析为同一个 version id。

version id 排序优先使用 `v<version>-r<release>` 语义：

1. 如果 version 可按点分数字比较，则按数字比较。
2. version 相同时按 release 正整数比较。
3. 如果无法解析，则退回字符串比较。

## version record

version record 是具体发布版本。

核心字段：

| 字段 | 类型 | 必需 | 说明 |
| --- | --- | --- | --- |
| `name` | string | 建议 | package 名称。 |
| `kind` | string | 建议 | `tool` 或 `flow`。 |
| `version` | string | 安装必需 | package version。 |
| `release` | integer/string | 安装必需 | release 编号。 |
| `version_id` | string | 建议 | `<version>-r<release>`。 |
| `tag` | string | 可选 | Git tag；默认 `v<version-id>`。 |
| `license` | string | 建议 | license id。 |
| `repository_url` | string | 建议 | canonical repository URL。 |
| `repository_slug` | string | 可选 | 例如 `taffish/demo`。 |
| `meta` | object | 可选 | 从 `taffish.toml` 的 `[meta]` 复制的发现元数据。 |
| `upstream` | object | 可选 | 从 `taffish.toml` 的 `[upstream]` 复制的上游溯源元数据。 |
| `command` | object | 安装必需 | command 信息。 |
| `runtime` | object | 建议 | 运行时信息。 |
| `paths` | object | 建议 | 项目内路径信息。 |
| `container` | object | 可选 | 容器信息。 |
| `smoke` | object | 可选 | 声明式 smoke 检查和 index 侧 smoke 结果。 |
| `source` | object | 安装建议 | source clone/copy 信息。 |
| `dependencies` | object | 可选 | 依赖 app 信息。 |

## `meta`

`meta` 记录 `taffish.toml` 中 `[meta]` 的发现元数据，用于搜索、分类和展示。
消费端应把它视为可选字段。

推荐字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `domain` | string | 大领域，例如 `bioinformatics`。 |
| `category` | string | 更细分领域，例如 `molecular-docking`。 |
| `summary` | string | 一句话描述。 |
| `keywords` | array | 搜索关键词和别名。 |

## `upstream`

`upstream` 记录 taf-app 包装的原始软件、方法、数据库或 workflow。它不同于
TAFFISH app 自己的包装仓库。

推荐字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | string | 上游软件、方法或资源名称。 |
| `type` | string | 可选来源类型，例如 `official`、`github`、`gitlab`、`archive`、`docker`、`apt`、`conda` 或 `other`。 |
| `version` | string | 当前 taf-app release 包装的上游版本。 |
| `url` | string | 上游主页、仓库或文档 URL。 |
| `homepage` | string | 与 `url` 不同时的上游主页。 |
| `repository` | string | 已知的上游源码仓库 URL 或 slug。 |
| `release_url` | string | 已知的上游发布页。 |
| `docker_image` | string | 已知的上游已有 Docker 镜像；这不是 TAFFISH 构建的镜像。 |
| `license` | string | 上游开源协议/许可证，已知时优先使用 SPDX identifier。 |
| `citation` | string | 简短 citation 文本。 |
| `doi` | string | 已知的上游方法或软件论文 DOI。 |
| `pmid` | string | 已知的上游方法或软件论文 PubMed ID。 |

Index 生成器应接受 `taffish.toml` 中的 `[upstream].repo` 作为兼容别名，并在
生成的 index record 中规范化为 `upstream.repository`。

`upstream.license` 描述上游软件或资源自己的 license；顶层 package 的
`license` 字段描述 TAFFISH wrapper 项目本身的 license。
对于学术型生信工具，`citation`、`doi` 和 `pmid` 用于保留经过确认的学术归属元数据。

index 侧 metadata override 可以为已经存在 upstream 的记录补充 `license`、
`citation`、`doi` 和 `pmid`，但不应该为原本没有 upstream 元数据的记录创建新的
upstream object。

## `command`

`command` object 至少应包含：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `name` | string | 安装时必需；必须是 taf command 名。 |

artifact 名称由消费端根据 command、version、release 计算：

```text
<command.name>-v<version>-r<release>
```

## `runtime`

建议字段：

| 字段 | 类型 |
| --- | --- |
| `pipe` | boolean |
| `command_mode` | boolean |

这些字段应来自 `taffish.toml` 的 `[runtime]`。

## `paths`

建议字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `main` | string | 主 TAF 文件路径。 |
| `help` | string | help 文件路径。 |
| `dockerfile` | string/null | Dockerfile 路径。 |

## `container`

建议字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `image` | string | 容器镜像。 |
| `image_tag` | string | 镜像 tag，通常等于 version id。 |
| `dockerfile` | string/null | Dockerfile 路径。 |
| `digest` | string | 可选不可变 OCI digest，例如 `sha256:...`。 |
| `platforms` | array | 可选支持平台列表，例如 `["linux/amd64"]`。 |

## `smoke`

`smoke` 记录 `taffish.toml` 中 `[smoke]` 的声明式检查，也可以记录 index 侧执行结果。

建议字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `backend` | string | smoke 推荐后端，例如 `docker`。 |
| `timeout` | integer | 每条 command 的超时时间，单位为秒。 |
| `exist` | array | 期望存在于容器 `PATH` 的可执行命令名。 |
| `test` | array | 期望以退出码 `0` 正常结束的 shell 命令。 |
| `status` | string | 可选生产端结果，例如 `passed`、`failed` 或 `skipped`。 |
| `checked_at` | string | 可选生产端 smoke 执行时间戳。 |

## `source`

安装时 source URL 解析优先级：

1. `source.local_path`
2. `source.clone_url`
3. `source.repository_url`
4. version record 顶层 `repository_url`

source ref 解析优先级：

1. `source.ref`
2. `tag`
3. `v<version-id>`

可选字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `local_path` | string | 本地源目录，主要用于开发和测试。 |
| `clone_url` | string | git clone URL。 |
| `repository_url` | string | canonical repository URL。 |
| `html_url` | string | 展示用 URL。 |
| `ref` | string | clone 的 branch/tag。 |
| `commit` | string | 记录源 commit。 |

source URL 在安装前会经过 config source rewrite。当 `commit` 存在时，
`taf install` 会在构建安装 command 前校验 resolved source 的 Git `HEAD`
commit 与该字段一致，并且源码工作区干净。官方公开 index producer 应为
release tag 记录写入 `source.commit`。

## trust metadata

对于官方公开 TAFFISH index，容器化 version record 应在 index producer 可以记录
以下信息后再被接纳：

1. source identity：repository、ref/tag 和 commit。
2. container identity：image tag、不可变 digest 和支持平台。
3. smoke result：声明式检查和 producer 侧通过状态。

消费端应把这些字段视为审计/可信元数据。它们不能替代对上游工具的科学验证，但可以让
交付路径从 index record 到源码 commit 和容器镜像都可追踪。

## `dependencies`

`dependencies` 是 object，key 是查询目标，value 是版本选择。

value 可以是：

1. `null`
2. `"latest"`
3. `"*"`
4. version id 字符串
5. version id 字符串数组

`null`、`latest`、`*` 均表示使用默认版本。

示例：

```json
{
  "dependencies": {
    "taf-fastqc": "0.12.1-r1",
    "taf-samtools": ["1.20-r1", "latest"]
  }
}
```

安装器必须检测循环依赖。

## 查询解析

`taf info/install` 的查询目标按以下顺序解析：

1. package name。
2. command name。
3. exact artifact name。

exact artifact name 形如：

```text
<command.name>-v<version>-r<release>
```

如果用户查询的是 exact artifact name，同时又传入不一致的 version id，应报错。

## index 更新

`taf update` 支持：

1. 本地文件路径。
2. `file://` URL。
3. `http://` 或 `https://` URL。

更新后应写入：

```text
<home>/index/current.json
<home>/index/snapshots/index-<timestamp>.json
```

index 下载失败通常应提示网络或代理问题，并允许用户通过 `taf update --url <INDEX-URL>` 或 `TAFFISH_INDEX_URL` 指定来源。
