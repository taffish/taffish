# compiler.lisp 与 main.lisp

`compiler.lisp` 负责把已绑定的 `taf-result` 转换为最终 shell 字符串。`main.lisp` 提供外部最常用的 `taffish-to-shell` 入口。

## 作用

compiler 不再理解用户输入或 TAF 源码结构。它接收 binder 已经整理好的结果，完成三件事：

1. 把 `::arg::` token 解析为实际值。
2. 把 RUN block 转换为 resolved block。
3. 调用 emitter 生成 shell。

## token 解析

`%resolve-taf-token` 的规则：

| token kind | 结果 |
| --- | --- |
| `:text` | 直接返回 token value。 |
| `:arg` | 从 `han.args:get-arg` 查询绑定值，缺失时报错。 |

arg 值为 `nil` 时会输出空字符串。

## line 与 block 解析

compiler 内部使用 plist 表示 resolved line：

```lisp
(:line <line-string> :number <line-number>)
```

resolved block 的结构是：

```lisp
(:tag <tag-value> :lines <resolved-lines>)
```

其中 tag 来自 subtag head，lines 来自 subtag 下面的内容行。

## emitter 调用

`%emit-resolved-body` 会对每个 resolved block 调用：

```lisp
emit-block
```

因此 compiler 本身不需要知道 shell、container、taffish、taf-app 的具体实现。

## 编译入口

当前可用主入口是：

```lisp
compile-taf-result
```

它要求输入必须是 `taf-result`，输出完整 shell 字符串，开头为：

```sh
#!/bin/sh
```

`compile-taf` 是分发函数：如果输入是 `taf-result`，调用 `compile-taf-result`；如果输入是 `taf-program`，调用 `compile-taf-program`。

## 当前未实现接口

`compile-taf-program` 当前显式未实现：

```text
COMPILE-TAF-PROGRAM is not implemented yet.
```

这意味着外部调用者如果只有 `taf-program`，仍然需要先经过 `bind-taf`。当前稳定链路是：

```text
parse-taf -> bind-taf -> compile-taf-result
```

## main.lisp

`taffish-to-shell` 封装完整链路：

```text
taf-code + input-args + context
  -> parse-taf
  -> bind-taf
  -> compile-taf
```

这是外部最适合调用的高层 API。

## 修改指南

修改 compiler 时应注意：

1. 不要把具体 tag 行为写入 compiler。
2. 新增 token kind 时必须更新 `%resolve-taf-token`。
3. 改变 resolved-line 或 resolved-block 结构会影响所有 emitter。
4. 如果实现 `compile-taf-program`，需要明确默认 args/context 策略，否则容易产生隐式行为。
