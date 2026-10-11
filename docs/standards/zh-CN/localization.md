# TAFFISH 本地化契约

本页定义语言选择、回退、外部语言包目录，以及人类文本与稳定机器接口之间的边界。

## 范围

TAFFISH 本地化是附加的表现层，可以翻译：

1. `taf`、`taffish` 与 `taffish-mcp` 的人类 CLI help 文本。
2. `taf` parser 诊断。
3. `taf` 产生的 project、Hub、package 管理、config、doctor 与 history 状态和诊断。

`taffish` 编译器的核心诊断仍可能使用英文基准。taf-app 或外部进程拥有的输出会原样透传，
不会进入本地化层。

本地化不得改变：

1. executable、command、subcommand 或 option 名。
2. exit code、TAF 语法或生成 shell。
3. JSON key、schema version、枚举值、config key、history 字段或 Hub index 字段。
4. MCP tool/resource/prompt 名、schema、description 或结构化结果。
5. taf-app stdout/stderr，或 git、gh、curl、容器后端及其他外部进程的原始 stdout/stderr。

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

CLI 只在进程入口解析一次语言。同一次调用中的全部人类 renderer 共用这一动态语言上下文；
不会在消息之间反复读取 config 或 locale 环境变量。

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

外部语言包由相互独立的人类表现组件组成：help 文件覆盖 `taf` 与 `taffish` help，
`messages.json` 覆盖 `taf` 使用的已注册运行时 semantic message。语言包可以只提供其中一种，
也可以只覆盖部分 command、help 或 message；缺失组件和 key 继续走正常回退链。

`taffish-mcp -h` 内置英文和中文；选择其他语言时回退到英文。这不会影响固定英文的 MCP 协议。

语言目录只有包含非空且有效的 `messages.json` object，或至少一个已识别的非空 help 文件时，
才会被发现。空目录、损坏目录和只有 `example.txt` 的目录都会被忽略。目录名应使用
`taf config language` 展示的规范 locale 拼写。

`example.txt` 是可选展示元数据。TAFFISH 只读取第一条非空 UTF-8 文本行，并截断到
256 个字符；它不能让其他内容无效的语言包成为可选项。

`messages.json` 是 JSON object，key 必须是已有 TAFFISH semantic message key，value 是
翻译字符串：

```json
{
  "taf.project.check.header": "Proyecto válido: {name}",
  "taf.project.check.field.root": "directorio raíz"
}
```

命名 placeholder 必须与英文基准完全一致。缺少或多出 placeholder 时只忽略对应 key。
help 文件是纯 UTF-8 文本，也执行相同的 placeholder 检查；某个条目缺失或无效，不会影响
有效 sibling key 或其他 help 文件。

对于同一个 locale，有效 user pack 会遮蔽对应 system pack；精确 locale 文件先于基础语言
文件。发现过程只扫描直接子目录并稳定排序。外部文件不能覆盖内置 `en` 或 `zh` catalog。

## 安全与失败策略

语言包只能是数据，不能是可执行代码。实现通过 `han.json` 读取 JSON，通过纯文本接口读取
help；不会执行 Lisp form，也不会使用 Lisp reader 处理语言包内容。

文件缺失、JSON 损坏、非字符串 value、非法路径组成或 placeholder 不一致都采用软失败。
TAFFISH 会忽略无效候选并继续回退。损坏的可选语言包不得阻止 CLI 启动。

## 人类排版与诊断摘要

Hub/doctor 字段渲染采用共享、与语言无关的显示宽度 helper，不按语言补空格，也不把字符数
当作显示列数。只保守支持部分 Unicode 窄/宽字符及附着于受支持基字符的组合标记；宽度
有歧义、需 shaping 的文字、emoji 序列、控制字符及未支持字符不猜测。这不是完整 Unicode
grapheme 引擎，也不精确模拟所有终端/字体。

长标签、长值、多行或宽度不确定的文本使用 label/value 分行，值不截断、不自动折行。
布局预算固定，不查询终端尺寸；对齐不规范化或改写路径/身份值，也不影响机器输出。

Hub 默认诊断在所选作用域内按问题类型/状态和处理策略合并重复问题，包含计数及每组至多
三个例子。摘要例子可缩短并清理控制字符；`--verbose` 和 JSON 保留完整证据。中英文必须
保留相同计数、分类、预览/执行区别和安全建议。

人类进度只写 stderr：交互式 TTY 原地更新阶段/计数，日志限频逐行输出。非 TTY 流及
`TERM=dumb` 不应收到光标控制序列。JSON/MCP 调用禁止进度文字。这只改变展示，不改变
诊断状态、退出码或机器 schema。

## 兼容性

在 semantic key、placeholder、command token、机器 schema、默认 `auto` 选择契约和最终
英文回退都不变时，新增翻译属于兼容变化。删除或重命名 semantic key，或改变其
placeholder 集合，需要执行兼容性复核并同步更新一致性测试。

## 操作阶段消息

慢命令阶段消息使用 `messages.json` 中的 `taf.progress.*` 命名空间，例如
`"taf.progress.download": "正在下载索引"` 可覆盖索引下载标签。应用身份及可选的
当前目标/总数由显示层添加；翻译标签不应自行添加计数或声称成功。
缺失消息沿用已有稀疏语言包回退。详见[命令状态与进度](../../dev/zh-CN/taf-core/command-progress.md)。
