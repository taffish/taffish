# TAFFISH 本地化契约

本页定义语言选择、回退、外部语言包目录，以及人类文本与稳定机器接口之间的边界。

## 范围

TAFFISH 本地化是附加的表现层，可以翻译：

1. `taf`、`taffish` 与 `taffish-mcp` 的人类 CLI help 文本。
2. 常见顶层 CLI 诊断。
3. 面向用户的 `taf config` 输出。
4. 面向用户的 `taf doctor` 诊断与修复建议。

project、Hub、install 和 compiler 的部分底层诊断仍可能使用英文回退。当前实现不宣称已经
翻译每一条面向用户的字符串。

本地化不得改变：

1. executable、command、subcommand 或 option 名。
2. exit code、TAF 语法或生成 shell。
3. JSON key、schema version、枚举值、config key、history 字段或 Hub index 字段。
4. MCP tool/resource/prompt 名、schema、description 或结构化结果。

## 内置语言

规范的内置语言标识是：

```text
en
zh
```

两套 catalog 都嵌入交付二进制，不依赖外部 locale 目录。人类 CLI 的选择模式默认是
`auto`；`en` 是完整基准、library/MCP 的确定性默认值和最终回退。常见别名会这样规范化：

```text
en-US, en_US       -> en
zh-CN, zh_CN       -> zh
zh-Hans            -> zh
```

其他标识使用保守的 BCP 47 风格，例如 `ja-JP`。

## 语言解析

面向用户的 CLI 按以下顺序解析语言：

1. `TAFFISH_LANGUAGE`。
2. `TAFFISH_CONFIG` 指向的显式配置。
3. `$TAFFISH_USER_HOME/config.toml` 或默认路径下的 user config。
4. `$TAFFISH_SYSTEM_HOME/config.toml` 或默认路径下的 system config。
5. 隐含的 `auto` 选择。

选中 `auto` 时都会读取 `LC_ALL`、`LC_MESSAGES` 和 `LANG`，其中也包括 config 没有提供
language 的情况。locale 不可用、未设置、为 `C` 或 `POSIX` 时解析为 `en`。如果人类输出
必须跨机器保持确定，应显式保存 `en` 或 `zh`。`taffish-mcp -h` 这一人类 CLI 表面遵循
同一解析规则。library 调用不会隐式继承人类 CLI 本地化；调用方可以为人类 renderer 显式
建立语言上下文。无论人类 CLI 选择何种语言，MCP stdio 协议始终保持英文。

catalog 按以下顺序查找：

```text
精确 locale -> 基础语言 -> en
```

例如 `ja-JP` 会依次回退到 `ja` 和 `en`。

## 语言管理 CLI

优先使用 config 命令，而不是手工修改语言偏好：

```text
taf config language
taf config language --show
taf config language en
taf config language zh
taf config language auto
taf config language <external-locale>
taf config language <language> --system
```

前两个命令等价且只读，会分别展示 configured language、实际 displayed language、决定来源、
相关 config file，以及全部内置和有效外部语言。当 `TAFFISH_LANGUAGE` 临时遮蔽已保存设置时，
这种区分尤其重要。

setter 默认写 user scope；system scope 需要 root。它只改变顶层 `language` assignment，保留
注释、section、source profile、index 设置和未知的未来字段。`en`、`zh`、`auto` 始终可选；
其他值必须对应 `--show` 当前列出的有效外部语言包。

## 外部语言包

外部语言包是高级用户的可选能力，目录为：

```text
$TAFFISH_SYSTEM_HOME/share/locales/<locale>/
$TAFFISH_USER_HOME/share/locales/<locale>/
```

支持的文件：

```text
messages.json
example.txt
help/taf.txt
help/taf/<command>.txt
help/taffish.txt
```

外部语言包目前可以覆盖 `taf` 和 `taffish` help。`taffish-mcp -h` 内置英文和中文；选择
其他语言时回退到英文。这不会影响固定英文的 MCP 协议。

语言目录只有包含非空且有效的 `messages.json` object，或至少一个已识别的非空 help 文件时，
才会被发现。空目录、损坏目录和只有 `example.txt` 的目录都会被忽略。目录名应使用
`taf config language` 展示的规范 locale 拼写。

`example.txt` 是可选展示元数据。TAFFISH 只读取第一条非空 UTF-8 文本行，并截断到
256 个字符；它不能让其他内容无效的语言包成为可选项。

`messages.json` 是 JSON object，key 必须是已有 TAFFISH semantic message key，value 是
翻译字符串：

```json
{
  "cli.unknown-option": "未知选项：{option}"
}
```

命名 placeholder 必须与英文基准完全一致。缺少或多出 placeholder 的翻译会被忽略。
help 文件是纯 UTF-8 文本，也执行相同的 placeholder 检查。

对于同一个 locale，有效 user pack 会遮蔽对应 system pack；精确 locale 文件先于基础语言
文件。发现过程只扫描直接子目录并稳定排序。外部文件不能覆盖内置 `en` 或 `zh` catalog。

## 安全与失败策略

语言包只能是数据，不能是可执行代码。实现通过 `han.json` 读取 JSON，通过纯文本接口读取
help；不会执行 Lisp form，也不会使用 Lisp reader 处理语言包内容。

文件缺失、JSON 损坏、非字符串 value、非法路径组成或 placeholder 不一致都采用软失败。
TAFFISH 会忽略无效候选并继续回退。损坏的可选语言包不得阻止 CLI 启动。

## 兼容性

在 semantic key、placeholder、command token、机器 schema、默认 `auto` 选择契约和最终
英文回退都不变时，新增翻译属于兼容变化。删除或重命名 semantic key，或改变其
placeholder 集合，需要执行兼容性复核并同步更新一致性测试。
