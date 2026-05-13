# ASDF 系统与模块地图

TAFFISH 使用 ASDF 描述 Common Lisp 系统。当前主系统是 `taffish`，版本为 `0.8.1`，依赖内置基础库 `han`。ASDF 文件不仅是构建配置，也是一份非常重要的架构地图。

## 主系统加载顺序

`taffish.asd` 使用 `:serial t`。这意味着模块按文件顺序加载，后面的文件可以依赖前面的定义。这个顺序本身就是一条依赖链，不应随意调整。

当前顺序可以分为五组，再加上面向 AI 的 MCP 层：

```text
taffish-core
  package
  model
  lexer
  parser
  input
  binder
  emitter/model
  emitter/registry
  emitter/builtins/taf-app
  emitter/builtins/taffish
  emitter/builtins/shell
  emitter/builtins/container
  compiler
  main

taffish-cli
  package
  run
  main

taf-core
  package
  project/common
  project/new
  project/check
  project/compile
  project/build
  project/run
  project/publish
  hub/update
  hub/info
  hub/search
  hub/install
  hub/uninstall
  hub/list
  hub/which
  system/home
  system/config
  system/history
  system/doctor

taf-cli
  package
  run
  main

taffish-mcp
  package
  protocol
  tools
  resources
  prompts
  server
  main
```

## 加载顺序背后的意义

`taffish-core` 先加载，因为它定义了 TAF 语言从源码到 shell 的完整编译能力。`taffish-cli` 只是在其上包了一层命令行入口。

`taf-core` 后加载，因为它需要把 `taffish-core` 的编译能力接入项目系统、hub 系统和运行系统。`taf-cli` 是用户命令的分发入口。`taffish-mcp` 在 CLI/core 模块之后加载，因为它是在已有 API 上提供一个保守的 AI 协议层，而不是定义新的业务逻辑。

## han 系统

`vendor/han/han.asd` 定义了内置基础库。它当前被拆为：

```text
test
host
source
os
path
json
args
```

`han` 的定位不是 TAFFISH 业务逻辑，而是 TAFFISH 需要的一组稳定底座。比如参数规格解析放在 `han.args`，JSON 解析放在 `han.json`，路径处理放在 `han.path`，这样 `taffish-core` 和 `taf-core` 不需要重复实现这些基础能力。

## 包和系统的关系

TAFFISH 的包边界大体和系统边界一致：

| 包 | 主要目录 | 说明 |
| --- | --- | --- |
| `taffish-core` | `taffish-core/` | TAF 编译器核心 API。 |
| `taffish-cli` | `taffish-cli/` | `taffish` 命令实现。 |
| `taf-core` | `taf-core/` | `taf` 命令背后的核心业务 API。 |
| `taf-cli` | `taf-cli/` | `taf` 命令实现。 |
| `taffish.mcp` | `taffish-mcp/` | 面向 AI 客户端的 MCP stdio server。 |
| `han.*` | `vendor/han/` | 基础库子包。 |

如果新增文件，优先判断它属于哪个包的职责，而不是先判断它放在哪个目录。目录只是包和系统边界的落地形式。

## 修改 ASDF 的检查点

修改 `taffish.asd` 或 `vendor/han/han.asd` 前，应检查：

1. 新文件是否真的需要公开给系统加载。
2. 它依赖的结构、函数、宏是否已经在它之前加载。
3. 是否引入了反向依赖，例如 `taffish-core` 调用 `taf-core`。
4. 是否需要更新对应 package 的 `:export`。
5. 是否需要更新本文档和对应模块文档。

最常见的风险是把“上层命令行为”放进“下层语言核心”。例如 hub、install、project metadata 这些概念属于 `taf-core`，不应该污染 `taffish-core`。
