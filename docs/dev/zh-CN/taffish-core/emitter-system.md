# Emitter 系统

Emitter 是 `taffish-core` 中负责把 TAF 块转换为 shell 片段的扩展机制。它让 TAF 语言可以支持不同标签，而不需要把所有标签逻辑写死在 compiler 中。

## 作用

TAF 程序中的运行块会带有标签，例如 shell、container、taffish、taf-app。不同标签对应不同的 shell 生成策略。

Emitter 系统解决的问题是：

1. 如何根据标签选择实现。
2. 如何统一标签实现的输入输出。
3. 如何让新增标签不破坏 compiler 主流程。

## 系统位置

```text
compiler
  -> emit-block
  -> registered emitter
  -> shell lines
```

compiler 只负责把块交给 emitter。具体怎么把块变成 shell，由匹配到的 emitter 决定。

## 核心文件

| 文件 | 作用 |
| --- | --- |
| `emitter/model.lisp` | 定义 emitter、默认 prelude、默认 finalize。 |
| `emitter/registry.lisp` | 注册 emitter，按块匹配 emitter，执行发射。 |
| `emitter/builtins/shell.lisp` | 直接输出 shell 行。 |
| `emitter/builtins/container.lisp` | 生成 Docker、Podman、Apptainer 等容器运行 shell。 |
| `emitter/builtins/taffish.lisp` | 支持 TAF 内联组合和子脚本编译。 |
| `emitter/builtins/taf-app.lisp` | 支持 taf-app 命令模式与应用入口委托。 |

## Emitter 契约

一个 emitter 至少需要回答三件事：

1. 它匹配哪些标签。
2. 它如何把 block 转换为 shell。
3. 它是否需要额外 prelude 或 finalize。

输出必须保持 shell 片段的可组合性。通常 emitter 返回字符串或字符串列表，registry 会负责基本检查。

## 内置标签定位

| 标签能力 | 定位 |
| --- | --- |
| shell | 最基础的直通执行模型。 |
| container | TAFFISH 可移植性的关键实现之一。 |
| taffish | 支持 TAF 组合 TAF，形成更高级流程。 |
| taf-app | 把底层 TAF 编译结果接入应用命令模式。 |

## 修改指南

新增 emitter 时应注意：

1. 不要修改 compiler 的主流程来适配单个标签。
2. 标签匹配逻辑应该清楚，避免和已有标签产生歧义。
3. 输出 shell 时要考虑 quoting、工作目录、临时文件、容器后端差异。
4. 如果新增标签影响 TAF 标准，需要同步更新标准文档。

修改 container emitter 时尤其要谨慎，因为它同时影响可移植性、安全边界、运行路径和用户数据挂载。
