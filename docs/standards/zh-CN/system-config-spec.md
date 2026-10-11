# TAFFISH 配置规范

本页定义 `config.toml` 的 schema、读取顺序和 source rewrite 规则。

## schema

当前配置 schema：

```toml
schema_version = "taffish.config/v1"
```

缺省配置等价于：

```toml
schema_version = "taffish.config/v1"
profile = "github"
language = "auto"

[index]
url = "https://raw.githubusercontent.com/taffish/taffish-index/main/index/index.json"
```

## 支持的 TOML 子集

配置文件使用与 `taffish.toml` 类似的受限 TOML 子集：

1. 顶层 key。
2. `[index]` section。
3. `[[source.rewrite]]` 表数组形式。
4. 字符串和布尔值。
5. 整行注释与空行。

当前不支持任意 TOML section。遇到未知 section 或未知 key 应报错。

## 顶层字段

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `schema_version` | string | 必须是 `taffish.config/v1`。 |
| `profile` | string | 当前内置 `github` 与 `china`。 |
| `language` | string | 面向用户的 CLI 语言选择，默认 `auto`；内置 `en` 与 `zh`，`auto` 跟随主机 locale 并最终回退到 `en`。 |

## 人类语言解析

面向用户的 CLI 使用顶层 `language` 字段，但不会改变 Hub 和 system API 使用的普通
effective-config 合并。语言选择优先级是：

1. `TAFFISH_LANGUAGE`。
2. `TAFFISH_CONFIG` 指向的显式 config。
3. user config。
4. system config。
5. 隐含的 `auto` 选择。

选中 `auto` 时会读取 `LC_ALL`、`LC_MESSAGES` 和 `LANG`，其中也包括 config 没有提供
language 的情况。`en-US`、`zh-CN` 等值会规范化到内置 `en`、`zh`；其他 locale 标识
可以选择外部语言包。主机 locale 缺失或不可识别，以及可选语言数据无效时都会软失败并
回退英文；普通 effective-config parser 仍保留下文的严格错误策略。需要确定性人类输出时，
应显式保存 `en` 或 `zh`。

语言只影响面向用户的表现。机器接口、config key、生成 shell 和 MCP 契约保持稳定。
详见[本地化契约](localization.md)。

外部 help 与运行时 message 组件彼此独立、均为可选。缺失或无效条目逐 semantic key 回退，
不会改变同一命令其余输出已经选择的语言。

使用 `taf config language` 查看解析结果和已发现语言包；使用
`taf config language <LANGUAGE>` 更新偏好而不重写其他 config 内容。root 管理的 system
scope 需要增加 `--system`。

## `[index]`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `url` | string | hub index 的默认 URL。 |

index URL 解析优先级：

1. 命令显式传入的 URL。
2. 环境变量 `TAFFISH_INDEX_URL`。
3. 运行时变量 `*taffish-index-default-url*`。
4. 有效配置中的 `[index].url`。
5. 内置 GitHub 默认 index URL。

## `[[source.rewrite]]`

source rewrite 用于把 canonical source URL 重写为镜像 URL。典型场景是中国大陆用户从 Gitee 镜像 clone app 源码。

字段：

| 字段 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `from` | string | 无 | canonical URL 前缀。 |
| `to` | string | 无 | 重写后的 URL 前缀。 |
| `enabled` | boolean | `true` | 是否启用该规则。 |

规则按顺序匹配。第一个启用且 `from` 是 canonical URL 前缀的规则生效。

示例：

```toml
[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

## 内置 profile

`github` profile 使用 GitHub index：

```toml
schema_version = "taffish.config/v1"
profile = "github"
language = "auto"

[index]
url = "https://raw.githubusercontent.com/taffish/taffish-index/main/index/index.json"
```

`china` profile 使用 Gitee index，并把 GitHub source 重写到 Gitee：

```toml
schema_version = "taffish.config/v1"
profile = "china"
language = "auto"

[index]
url = "https://gitee.com/taffish-org/taffish-index/raw/main/index/index.json"

[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

注意：GitHub canonical 组织是 `taffish`，Gitee 镜像组织是 `taffish-org`。

## 配置合并顺序

有效配置从默认配置开始，按顺序覆盖：

1. system config。
2. user config，仅 user scope 时读取。
3. `TAFFISH_CONFIG` 指定的显式配置。

后加载的配置覆盖先加载的同名字段。`source.rewrite` 规则作为整体字段覆盖，而不是逐条合并。

## 错误策略

配置文件中：

1. 未知 schema 必须报错。
2. 未知 section 必须报错。
3. 未知 key 必须报错。
4. `from`、`to` 必须是非空字符串。
5. `enabled` 必须是布尔值。

这样做是为了避免错误配置被静默忽略，从而导致下载源、镜像源或 index 源不可复现。
