# hub/update、info、search

这组文件负责 hub index 的获取、加载、目标解析、信息展示和搜索。

## 作用

Hub index 是 TAFFISH 生态的目录。`hub/update` 把远程或本地 index 放到 TAFFISH home，`hub/info` 根据 query 定位 package/version record，`hub/search` 在 index 中搜索 package。

## hub/update

`hub-update` 的职责：

1. 解析 scope 和 home。
2. 解析 index URL。
3. 从本地文件、`file://`、HTTP(S) URL 读取 index。
4. 轻量校验 index 字符串。
5. 写入 `index/current.json`。
6. 写入 `index/snapshots/index-<timestamp>.json`。

index URL 来源优先级：

1. 显式 `index-url`。
2. 环境变量 `TAFFISH_INDEX_URL`。
3. 运行时变量 `*taffish-index-default-url*`。
4. system config 中的 `index-url`。
5. `%default-index-url`。

下载使用 `curl`，并设置 fail、retry、timeout 等参数。

## index 文件位置

在某个 TAFFISH home 下：

```text
index/current.json
index/snapshots/index-<timestamp>.json
```

`current.json` 是 hub 查询命令的默认读取对象。snapshots 用于保留历史 index。

## index schema

`hub/info` 会严格要求：

```text
schema_version = "taffish.index/v1"
```

并要求 index 是 JSON object，且包含 object 类型的 `packages` 和 `commands`。

## hub/info 目标解析

`%hub-resolve-info-target` 支持三类 query：

| query 类型 | 解析方式 |
| --- | --- |
| package name | 在 `packages` 中直接匹配。 |
| command name | 在 `commands` 中匹配，再回到 package。 |
| artifact name | 扫描 package versions，匹配 artifact 名。 |

version-id 会先规范化，允许传入带前缀 `v` 的形式。artifact query 自身已经包含版本时，不允许再传入冲突 version-id。

## version 排序

hub 复用 publish 的 version/release 解析比较逻辑。`v<version>-r<release>` 可被解析时，按版本号和 release 排序；否则退回字符串比较。

## hub/search

search 会：

1. 把 query 按空白切成多个 term。
2. 从 package、command、kind、version、repo、container image 等字段收集搜索域。
3. 要求所有 term 都能在某些字段中命中。
4. 按评分排序。
5. 支持 limit 和 JSON 输出。

评分大致偏好：

1. package name。
2. command name。
3. kind。
4. version。
5. repository。
6. container image。

## 修改指南

修改 hub index/query 层时要检查：

1. index schema 是否变化。
2. `hub-install` 是否仍能使用 `hub-info` 的解析结果。
3. package、command、artifact 三种 query 是否都保持可用。
4. GitHub/Gitee index URL 是否由 config 层统一管理。
5. JSON 输出是否适合脚本消费。
