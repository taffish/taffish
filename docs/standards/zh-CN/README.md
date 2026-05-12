# TAFFISH 规范草案与系统契约

本目录记录 TAFFISH 的规范草案与面向实现的系统契约。它不是外部公证标准，也不是类似 ANSI Common Lisp 那样的正式标准；它是当前参考实现和未来生态之间的稳定约定。

模块文档说明代码在哪里、怎么交互；规范文档说明哪些行为应该长期保持、哪些格式需要兼容、哪些变化必须有迁移路径。

## 当前标准主题

- [规范定位与版本策略](specification-policy.md)
- [兼容性策略](compatibility-policy.md)
- [合规性检查清单](conformance-checklist.md)
- [TAF 语言契约](taf-language-contract.md)
- [TAF 语言规范草案](taf-language-spec.md)
- [生成 shell 契约](generated-shell-contract.md)
- [TAFFISH 项目规范](taffish-project-spec.md)
- [TAFFISH home 与系统布局规范](system-home-spec.md)
- [TAFFISH 配置规范](system-config-spec.md)
- [TAFFISH hub index 规范](hub-index-spec.md)
- [TAFFISH 安装元数据规范](install-metadata-spec.md)
- [TAFFISH history 规范](history-spec.md)
- [TAFFISH 运行时与容器规范](runtime-container-spec.md)
- [TAFFISH MCP 接口规范](mcp-interface-spec.md)

## 为什么需要标准文档

TAFFISH 的代码规模还可以靠阅读源码理解，但随着 hub、taf-app、容器后端、镜像和自动发布逐渐变多，很多问题会变成“生态兼容性问题”，不只是“当前代码能不能跑”。

例如：

1. `.taf` 文件中某种写法是否应该长期支持？
2. 生成的 shell 是否必须保持 POSIX 兼容？
3. 容器后端的挂载行为是否应该统一？
4. hub index schema 变化如何兼容旧版本？

这些问题需要标准文档承接。否则每次修改都只能凭代码现状判断，很容易破坏已有 taf-app。

## 规范层级

TAFFISH 当前按四个层级治理：

| 层级 | 名称 | 当前状态 | 作用 |
| --- | --- | --- | --- |
| 1 | 开发文档 | 已建立 | 解释代码结构、模块职责、公开 API。 |
| 2 | 规范草案 | 当前重点 | 定义语言、项目、hub、安装、配置和运行时契约。 |
| 3 | 一致性测试 | 后续建立 | 验证某个实现或 taf-app 是否符合规范。 |
| 4 | 正式标准 | 暂不启动 | 当出现多个实现或外部治理需求时再考虑。 |

因此，本目录使用“规范草案”而不是“正式标准”作为起步形态。规范可以版本化演进，但不能随意漂移。

## 阅读约定

本目录中的规范性程度分为三类：

| 标记 | 含义 |
| --- | --- |
| 规范性 | 使用“必须、应该、可以”等关键词，描述 TAFFISH 长期兼容契约。 |
| 当前实现 | 描述当前 Common Lisp 参考实现的事实行为，未来可以被规范化或替换。 |
| 未稳定 | 已知仍在设计中，不建议外部生态依赖其细节。 |

如果某段文字没有显式标注，但包含 schema、文件路径、命名规则、解析顺序或错误条件，应优先按规范性文本理解。

## 成熟度地图

| 主题 | 当前成熟度 | 说明 |
| --- | --- | --- |
| TAF 基本语法 | Draft v0.1 稳定 | 行类型、`ARGS`/`RUN`、参数 token 和 block 结构已经成型。 |
| taf-app 项目格式 | Draft v0.1 稳定 | `taffish.toml`、artifact 名称和 wrapper 结构已有参考实现。 |
| hub index | Draft v0.1 待生态验证 | 消费端已经有实现，生产端还要通过 taffish-hub 迁移验证。 |
| install metadata | Draft v0.1 稳定 | 本地安装、list、which、uninstall 依赖这些字段。 |
| config/home/history | Draft v0.1 稳定 | 已有持久化路径和 schema，后续主要是扩展字段。 |
| runtime/container | Draft v0.1 半稳定 | 后端选择和基本挂载稳定，高级参数仍可能演进。 |
| MCP interface | Draft v0.1 核心稳定 | 已有保守 tools/resources/prompts；执行和发布仍不在范围内。 |
| 一致性测试 | 未建立 | 目前先用 checklist，后续再变成自动测试。 |

## 写作原则

标准文档应尽量写成稳定契约，而不是实现日记。它应该回答：

1. 哪些行为必须保持？
2. 哪些行为是当前实现细节？
3. 哪些行为还没有稳定，未来可能改变？
4. 改变契约时需要怎样迁移？

## 维护规则

修改以下内容时，必须同步检查本目录：

1. `.taf` 语法、标签、参数替换和编译行为。
2. `taffish.toml` 字段、项目目录、构建产物和发布流程。
3. hub index、安装元数据、配置文件和 history 输出。
4. 生成 shell、wrapper shell、容器后端和运行时环境变量。
5. GitHub/Gitee source rewrite、索引 URL、安装路径和命令别名规则。
6. MCP tool 名称、安全边界、结构化结果形状、resources 和 prompts。
