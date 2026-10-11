# taffish-cli

`taffish-cli` 是 `taffish` 命令的实现层。它把 `taffish-core` 的编译能力暴露给命令行用户。

## 作用

`taffish-cli` 的职责是处理命令行参数、读取输入、调用 `taffish-core`，并把结果输出给用户或调用方。

它不应该包含 TAF 语言语义。语言语义属于 `taffish-core`。

`main.lisp` 在 dispatch 前通过 `taffish.i18n` 建立人类语言上下文。`i18n.lisp` 负责内置
中英文 help 和顶层缺失命令诊断。编译器诊断与生成 shell 不进入本地化层。

## 帮助与输入

`taffish --help` 依次说明用法、输入、容器设置、示例、语言和联系入口。内置中英文
暴露相同选项；`--version` 保持单行命令名和版本号。

除帮助/版本选项和开头的 `--` 外，首参数为已存在的普通文件时选择文件输入，否则
读取标准输入并把参数交给 TAF 程序。不存在的文件名也属于后一种情况，拼错文件名
可能导致编译器等待终端输入。`taffish -- < example.taf > example.sh` 明确选择标准输入。

`TAFFISH_CONTAINER_BACKEND` 可选 `apptainer`、`podman`、`docker`。未设置时，为通用
`<container:...>` 标签自动选择可用后端；显式指定后端的标签不变。例如：

```sh
TAFFISH_CONTAINER_BACKEND=podman taffish example.taf > example.sh
```

编译通用容器标签时，指定的后端必须可用。该命令只生成 shell，不拉取镜像、不运行容器。
三个 `TAFFISH_*_RUN_ARGS` 设置分别追加对应后端的运行参数；语言选择不改变这些变量名
或生成的 shell。

## 错误处理

可执行入口使用同一内部错误边界覆盖 TAFFISH runtime I/O、语言初始化和逃逸的编译错误。
错误使用 `[TAFFISH-ERROR]` 前缀写入 stderr，并以状态码 1 退出；编译器的行号、列号及
定位符诊断保留。stderr 或错误呈现失败时仍以失败退出，不把用于生成 shell 的 stdout
当作备用错误输出通道。

这不会全局屏蔽库函数 condition 或 warning。实现相关的中断行为和错误边界限制见
[han.host](../han/host.md)。

## 系统位置

```text
user / script
  -> taffish command
  -> taffish-cli
  -> taffish-core
```

## 文件职责

| 文件 | 作用 |
| --- | --- |
| `package.lisp` | 定义 CLI 包。 |
| `i18n.lisp` | 管理本地化人类 help 和常见 CLI 诊断。 |
| `run.lisp` | 实现主要命令运行逻辑。 |
| `main.lisp` | 提供入口函数。 |

## 修改指南

修改 `taffish-cli` 时应注意：

1. CLI 参数变化是否需要同步 completion。
2. 输出格式是否被脚本或上层工具依赖。
3. 错误信息是否保留了 `taffish-core` 的定位信息。
4. 不要把 project、hub 或 install 逻辑加到这里。
5. 验证语言选择不会改变生成 shell 或 core 错误的位置信息。

如果某个需求是面向普通 taf-app 用户的完整工作流，通常应该进入 `taf-cli` 和 `taf-core`，而不是 `taffish-cli`。
