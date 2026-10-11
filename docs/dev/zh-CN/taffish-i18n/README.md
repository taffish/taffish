# taffish-i18n

`taffish-i18n` 是 `taf-cli`、`taffish-cli` 和 `taf-core` 全部人类 renderer 共用的表现层，
package 名是 `taffish.i18n`。

## 职责

本模块负责：

1. locale 规范化和确定性的语言选择。
2. 内置英文/中文 semantic message 与 help 选择。
3. 通过 `han.json` 和纯文本安全发现、加载外部语言包。
4. 只读解析 configured/displayed/source 详细信息。
5. 命名 placeholder 校验与回退。

它不负责 command 解析、业务逻辑、TAF 编译、Hub/index metadata、机器 schema 或 MCP
本地化。

## 依赖位置

```text
han
  -> taffish-i18n
       -> taffish-cli / taf-core 人类 renderer / taf-cli

taffish-core / taffish-mcp
  -> 只做语言不变性回归
```

本模块刻意不依赖 `taf-core`。它只从标准 config 路径读取顶层 `language`，从而让两个 CLI
共享语言选择，又不会形成反向依赖或 ASDF 环。

## 文件职责

| 文件 | 作用 |
| --- | --- |
| `package.lisp` | 定义 `taffish.i18n` API。 |
| `locale.lisp` | 规范化 locale、读取窄范围语言偏好并建立动态人类语言上下文。 |
| `render.lisp` | 校验命名 placeholder 并渲染模板。 |
| `catalog.lisp` | 按回退规则解析内置/外部 message 与 help。 |
| `builtin.lisp` | 注册共享 CLI message。 |
| `test.lisp` | 测试规范化、优先级、安全、回退和外部语言包。 |

program-specific help 和诊断在拥有相应人类措辞的 renderer 附近注册 semantic key，避免
共享模块积累 `taf-core` 业务概念。

## 公开 API

导出的 API 包括：

1. `normalize-language`、`language-fallback-chain`、`resolve-language`、
   `resolve-language-details`。
2. 用于确定性发现 built-in/user/system 语言的 `available-languages`。
3. `current-language`、`call-with-resolved-language`、`call-with-language`、
   `with-language`。
4. `register-message`、`message`、`message-with`、`help-text`、`builtin-message-keys`。

`taf-cli:main` 和 `taffish-cli:main` 会建立解析后的语言上下文。没有已配置偏好时，这两个人类
CLI 入口默认使用 `auto`，跟随可识别的主机 locale，并最终回退到英文。library 与 MCP
调用保持英文，除非调用方显式建立人类语言上下文；因此内部英文基准与人类 CLI 的默认选择
模式是两个刻意分开的概念。

`available-languages` 先列出内置 `en`/`zh`，再按 canonical ID 排序列出有效外部语言包；
user pack 会遮蔽 system pack。可选 `example.txt` 只贡献第一条非空行，最多 256 个字符，
不能单独使语言包变为有效。

help 文件和 `messages.json` 是相互独立的稀疏组件。查找按文件/semantic key 分别执行，
顺序是精确 locale、基础 locale、英文。CLI 入口每次调用只建立一次语言上下文，因此 core
renderer 应使用 `current-language`/`message`，不能再次解析 config。placeholder 无效时只拒绝
对应候选条目。

本模块刻意不修改配置。`taf.core:system-config-language` 根据发现结果校验语言，并只更新
config 的顶层语言字段。

## 安全与兼容

外部 locale 文件只是可选数据。不要用 `read`、求值 Lisp 或实现专用 API 替换
`han.json`/纯文本加载。外部文件不能覆盖内置 `en`、`zh`；无效文件必须回退，不能阻止启动。

修改本模块时，要验证所有 CLI help 的 option token、编译 shell 字节、JSON/history/config/
index 数据、外部进程输出以及 MCP tools/resources/prompts/results 都保持不变。规范行为见
[本地化契约](../../../standards/zh-CN/localization.md)。
