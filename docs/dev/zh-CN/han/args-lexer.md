# han.args 输入词法

`vendor/han/args/lexer.lisp` 把 raw argv 解析为 token 和 segment。它是参数绑定前的输入结构化步骤。

## 作用

lexer 接收类似：

```lisp
("cmd" "--input" "a.fa" "@run:" "blastn" "-query" "a.fa")
```

输出 `args-input`：

1. `raw-cmd`
2. `raw-argv`
3. token vector
4. segment list
5. diagnostics

## token 类型

| 输入形式 | kind | value | extra |
| --- | --- | --- | --- |
| `--name` | `:long-option` | `name` | nil |
| `--name=value` | `:long-option` | `name` | `value` |
| `-n` | `:short-option` | `n` | nil |
| `-n=value` | `:short-option` | `n` | `value` |
| `@slot:` | `:slot-switch` | `slot` | nil |
| `@:` | `:slot-switch` | nil | nil |
| 其他 | `:value` | 原字符串 | nil |

特殊情况会产生 warning，例如：

1. 单独的 `-`。
2. 单独的 `--`。
3. `---abc`。
4. `@xxx` 没有结尾 `:`。

这些 warning 不会阻止后续绑定，但会进入 diagnostics。

## segment

`parse-segments` 会按 slot switch 切分 token positions：

```text
默认 segment
@run: segment
@: 回到默认 segment
```

`arg-segment` 只保存 slot 名称和 token 位置，不直接复制 token。绑定阶段通过 position 回到 token vector。

## parse-args-input

`parse-args-input` 默认从 `han.host:argv` 读取输入，也可以显式传入 raw-input-args。

`add-cmd` 会被追加到 raw input 前面。TAFFISH 在 `normalize-input-args` 中用这个机制补默认命令名。

## 修改指南

修改 lexer 时要检查：

1. `bind.lisp` 对 token kind 的 case 是否同步。
2. slot 语法是否仍能表达 block 参数。
3. warning code/message 是否足够定位用户输入问题。
4. 不要在 lexer 阶段查 spec，这属于 bind 阶段。
