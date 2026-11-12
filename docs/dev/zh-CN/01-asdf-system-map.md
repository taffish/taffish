# ASDF 系统与模块地图

TAFFISH 0.12.0 的主系统是 `taffish`。[ASDF 定义](../../../taffish.asd)要求 Han Lisp 0.3.0 或以上版本，仓库随附 [Han Lisp 0.3.0](han/README.md)。

## 主系统加载顺序

`taffish.asd` 使用 `:serial t`。这意味着模块按文件顺序加载，后面的文件可以依赖前面的定义。这个顺序本身就是一条依赖链，不应随意调整。

当前顺序可以分为五组，再加上面向 AI 的 MCP 层：

```text
taffish-i18n
  package
  locale
  render
  catalog
  builtin

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

taf-core
  package
  version
  display
  progress
  project/i18n
  project/common
  project/digest
  project/new
  project/check
  project/compile
  project/build
  project/run
  project/publish
  hub/i18n
  hub/update
  hub/info
  hub/search
  hub/install
  hub/uninstall
  hub/list
  hub/which
  hub/diagnostics
  hub/repair
  hub/upgrade
  system/home
  system/config
  system/history-i18n
  system/history
  system/doctor-i18n
  system/doctor

taffish-cli
  package
  i18n
  run
  main

taf-cli
  package
  i18n
  run
  main

taffish-mcp
  package
  protocol
  i18n
  compiler
  app
  project
  tools
  resources
  prompts
  server
  main
```

## 开发系统

`taffish.dev.asd` 镜像生产系统的模块与文件顺序，然后在 `taffish-i18n`、`taffish-core`、
两个 CLI 模块、`taf-core` 的每个子系统和 `taffish-mcp` 后追加对应 `test.lisp`。因此开发
加载会验证与 delivery 相同的依赖顺序，同时不把测试定义带入 release binary。

共享的 `display` 和 `progress` helper 也有仅开发系统加载的测试文件。
`progress` 依赖已有显示宽度 helper，必须在需要报告人类状态的 project、Hub 命令实现之前加载。

生产 component 新增、删除或调整顺序时，必须同步修改 `taffish.asd` 与 `taffish.dev.asd`。
开发系统可以追加测试，但不能悄悄定义只在测试加载后才存在的业务行为。

## 加载顺序背后的意义

`taffish-i18n` 在 `han` 之后、语言与业务层之前加载，提供不依赖 `taf-core` 的窄人类表现
API。随后 `taffish-core` 定义 TAF 语言从源码到 shell 的完整编译能力，`taffish-cli`
只是在其上包一层命令行入口。

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
| `taffish.i18n` | `taffish-i18n/` | 共享的人类语言解析、catalog 与安全回退。 |
| `taffish-core` | `taffish-core/` | TAF 编译器核心 API。 |
| `taffish-cli` | `taffish-cli/` | `taffish` 命令实现。 |
| `taf-core` | `taf-core/` | `taf` 命令背后的核心业务 API。 |
| `taf-cli` | `taf-cli/` | `taf` 命令实现。 |
| `taffish.mcp` | `taffish-mcp/` | 面向 AI 客户端的 MCP stdio server。 |
| `han.*` | `vendor/han/` | 基础库子包。 |

如果新增文件，优先判断它属于哪个包的职责，而不是先判断它放在哪个目录。目录只是包和系统边界的落地形式。

## 修改 ASDF 的检查点

修改 `taffish.asd`、`taffish.dev.asd` 或 `vendor/han/han.asd` 前，应检查：

1. 新文件是否真的需要公开给系统加载。
2. 它依赖的结构、函数、宏是否已经在它之前加载。
3. 是否引入了反向依赖，例如 `taffish-core` 调用 `taf-core`。
4. 是否需要更新对应 package 的 `:export`。
5. 是否需要更新本文档和对应模块文档。

最常见的风险是把“上层命令行为”放进“下层语言核心”。例如 hub、install、project metadata 这些概念属于 `taf-core`，不应该污染 `taffish-core`。
