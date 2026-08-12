# taffish-cli

`taffish-cli` 是 `taffish` 命令的实现层。它把 `taffish-core` 的编译能力暴露给命令行用户。

## 作用

`taffish-cli` 的职责是处理命令行参数、读取输入、调用 `taffish-core`，并把结果输出给用户或调用方。

它不应该包含 TAF 语言语义。语言语义属于 `taffish-core`。

`main.lisp` 在 dispatch 前通过 `taffish.i18n` 建立人类语言上下文。`i18n.lisp` 负责内置
中英文 help 和顶层缺失命令诊断。编译器诊断与生成 shell 不进入本地化层。

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
