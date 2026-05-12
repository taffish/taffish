# han ASDF 与包边界

`han` 是 TAFFISH 内置基础库，ASDF 系统名为 `han`，版本为 `0.1.0`。它被 `taffish.asd` 作为依赖加载。

## 加载顺序

`vendor/han/han.asd` 使用 `:serial t`，当前顺序是：

```text
test
host
source
os
path
json
args
```

这个顺序反映了依赖方向：

1. `test` 最小化，用于其他 han 子系统测试。
2. `host` 隔离 Lisp 实现差异。
3. `source` 提供字符游标抽象。
4. `os` 在 host 上封装文件、环境和 shell。
5. `path` 在 host 上封装 pathname。
6. `json` 提供 index/config/metadata 所需 JSON。
7. `args` 提供 TAFFISH 参数系统。

## 包职责

| 包 | 目录 | 作用 |
| --- | --- | --- |
| `han.test` | `test/` | 极小测试框架。 |
| `han.host` | `host/` | SBCL/LispWorks 等实现差异适配。 |
| `han.source` | `source/` | 字符源、mark、span、匹配与消费。 |
| `han.os` | `os/` | IO、环境变量、可执行查找、shell 命令运行。 |
| `han.path` | `path/` | pathname 规范化、join、relative、文件目录操作。 |
| `han.json` | `json/` | JSON 解析、编码、读写。 |
| `han.args` | `args/` | argv 词法、参数规格、绑定、查询。 |

## 依赖边界

`han` 不应该依赖 TAFFISH 业务包。尤其不要让它知道：

1. TAF 语言。
2. taf-app。
3. hub index schema。
4. GitHub/Gitee 组织结构。
5. 生物信息学工具语义。

如果某个能力会被 TAFFISH 多层复用，并且与业务无关，可以考虑放进 `han`。如果它只服务 hub、project 或 TAF 编译器，应留在对应上层。

## 修改 ASDF 的检查点

新增 han 文件时要检查：

1. 是否真的属于基础库。
2. 是否会引入对 TAFFISH 上层包的反向依赖。
3. 是否需要导出 API。
4. 是否影响 ASDF 加载顺序。
5. 是否需要补对应细化文档。
