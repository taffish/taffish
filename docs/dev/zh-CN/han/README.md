# han 基础库

`han` 是 TAFFISH 内置的基础库，位于 `vendor/han/`。它不是独立业务层，而是为 TAFFISH 提供跨平台、解析、路径、JSON、命令行参数等基础能力。

## 作用

TAFFISH 需要在不同系统上稳定处理路径、环境变量、外部命令、JSON、参数规格和测试。这些能力如果散落在 `taffish-core` 与 `taf-core` 中，会让业务逻辑很快变得难以维护。

`han` 的存在意义就是把这些通用能力集中起来，让上层代码可以依赖稳定接口，而不是反复处理底层细节。

## 系统位置

```text
vendor/han
  -> taffish-core
  -> taf-core
```

`han` 位于 TAFFISH 依赖链最底部。它不应该依赖 `taffish-core` 或 `taf-core`。如果 `han` 开始知道 TAF 语言或 hub 概念，说明边界已经被污染。

## 子系统

| 子系统 | 路径 | 作用 |
| --- | --- | --- |
| `han.test` | `test/` | 简单测试框架或测试辅助。 |
| `han.host` | `host/` | 宿主实现差异、参数、平台相关实现。 |
| `han.source` | `source/` | 字符源抽象。 |
| `han.os` | `os/` | IO、环境变量、shell 命令运行等 OS 能力。 |
| `han.path` | `path/` | 路径处理与规范化。 |
| `han.json` | `json/` | JSON 编码和解码。 |
| `han.args` | `args/` | 命令行参数规格、词法、绑定和查询。 |

## han.args 的特殊地位

`han.args` 是 TAFFISH 参数系统的基础。TAF 的 `ARGS` 块最终会被 parser 转换为 `han.args` 可理解的参数规格。binder 再使用 `han.args` 把外部输入绑定到程序结果。

这意味着：

1. TAF 参数语法的高级语义不应该散落在 CLI 层。
2. 参数默认值、required、flag、repeat 等规则应尽量保持在 `han.args` 的契约内。
3. 如果修改 `han.args` 返回结构，必须检查 `taffish-core/parser.lisp`、`taffish-core/input.lisp` 和 `taffish-core/binder.lisp`。

## han.host 的作用

`han.host` 用于隔离 Common Lisp 实现差异。当前系统中有 SBCL、LispWorks 和 unsupported 的实现文件。TAFFISH 的主要目标是形成稳定命令行工具，所以宿主差异不能泄漏到上层业务逻辑。

如果某个上层模块需要判断 Lisp 实现，优先考虑是否应该把判断下沉到 `han.host`。

## 修改指南

修改 `han` 时要比修改上层代码更谨慎，因为它的影响面更大：

1. 不要引入对 TAFFISH 业务概念的依赖。
2. 保持返回值简单、明确、可组合。
3. 错误信息可以帮助定位底层问题，但不要假设调用者一定是 `taf` 或 `taffish`。
4. 修改 `han.args`、`han.json`、`han.path` 后，应检查所有直接调用点。

## 后续完善方向

`han` 已经独立形成了一组细化文档。后续如果继续扩展，可以重点完善：

1. `han.args` 参数规格与绑定。
2. `han.path` 路径规范。
3. `han.json` 支持范围。
4. `han.os` 外部命令与环境变量约定。

## 细化文档

- [ASDF 与包边界](system-map.md)
- [han.args 总览](args-overview.md)
- [han.args 输入词法](args-lexer.md)
- [han.args 参数规格](args-spec.md)
- [han.args 绑定与查询](args-bind-query.md)
- [han.source 字符源](source.md)
- [han.path 路径工具](path.md)
- [han.json JSON 工具](json.md)
- [han.os OS 工具](os.md)
- [han.host 宿主适配层](host.md)
- [han.test 测试工具](test.md)
