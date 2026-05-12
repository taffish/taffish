# hub/list、which

`hub/list.lisp` 负责列出本地已安装 app 或 index 中的 app。`hub/which.lisp` 负责定位某个本地安装的具体文件。

## hub/list

`hub-list` 有两种 mode：

| mode | 含义 |
| --- | --- |
| `:local` / `:installed` | 列出本地已安装 app。 |
| `:online` / `:index` | 列出本地 index 中的 app。 |

它支持 scope、limit、JSON 输出。

## local list

local list 通过扫描：

```text
apps/*/*/install.json
```

读取 install metadata，输出：

1. package name。
2. version id。
3. artifact name。
4. command name。
5. launcher file。
6. bin dir。
7. command file。
8. install root。
9. source dir。
10. metadata file。
11. repository/source/ref/commit。
12. origin kind/value/display。
13. installed_at。
14. 文件存在状态。

local items 按 package name 排序，同一 package 下新版本优先。

## online list

online list 读取 `index/current.json` 的 packages，并展示每个 package 的 latest record：

1. name。
2. latest version id。
3. versions。
4. kind。
5. command name。
6. repository URL。
7. container image。

## JSON schema

`hub-list` JSON 输出 schema：

```text
taffish.list/v1
```

这适合后续脚本、GUI 或 hub 管理工具消费。

## hub/which

`hub-which` 用于定位本地安装：

1. 找到匹配的 install entry。
2. 读取 command file、repository、source ref、source commit 和 origin。
3. 检查 launcher、command、install root、source dir、metadata 是否存在。
4. 检查 bin 是否在 PATH。

JSON 输出 schema：

```text
taffish.which/v1
```

## which 匹配规则

`which` 复用 uninstall 的匹配逻辑，可以按：

1. package name。
2. artifact name。
3. command base。

如果多版本匹配，需要指定 version-id。

## 修改指南

修改 list/which 时要检查：

1. install metadata 字段是否变化。
2. JSON schema 是否需要升级。
3. 多版本排序是否和 install alias 逻辑一致。
4. PATH 检查是否和 system/home 中的 bin 规则一致。
