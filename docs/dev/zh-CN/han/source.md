# han.source 字符源

`han.source` 提供可追踪位置的字符游标，是 lexer 和 parser 的底层输入抽象。

## 作用

直接用字符串 index 写 lexer 很容易丢失 line/column，也难以回退。`han.source` 把字符串包装成 mutable cursor，并提供 mark、span、peek、consume 等操作。

TAFFISH 的 TAF lexer 和 `han.args` 的部分扫描逻辑都依赖类似能力。

## 核心结构

| 结构 | 作用 |
| --- | --- |
| `char-source` | 包含 id、string、length、index、line、column。 |
| `char-source-mark` | 保存某个 source 的 index/line/column。 |
| `char-source-span` | 同一 source 中 start 到 end 的范围。 |

每个 source 有独立 id。mark/span 会记录来源，防止拿一个 source 的 mark 去 reset 另一个 source。

## 位置模型

`source-location` 返回三个值：

```lisp
index, line, column
```

line 和 column 从 1 开始。`source-next-char` 读到 newline 时 line 加 1，column 重置为 1；其他字符使 column 加 1。

## 常用 API

| API | 作用 |
| --- | --- |
| `make-char-source` | 从字符串创建 source。 |
| `source-eof-p` | 是否到达 EOF。 |
| `source-peek-char` | 查看当前字符但不前进。 |
| `source-next-char` | 读取当前字符并前进。 |
| `source-match-char-p` | 判断当前字符是否匹配。 |
| `source-match-string-p` | 判断当前位置是否匹配字符串。 |
| `source-consume-char-if` | 匹配则消费一个字符。 |
| `source-consume-string-if` | 匹配则消费字符串。 |
| `source-skip-while` | 持续跳过满足 predicate 的字符。 |
| `source-read-while` | 持续读取满足 predicate 的字符并返回字符串。 |

## mark 与 span

`make-source-mark` 保存当前位置。`source-reset` 可以回到这个位置。

`make-source-span` 要求 start 和 end 来自同一个 source，且 end index 不小于 start index。`source-slice-by-span` 可用 span 取原始字符串片段。

## 修改指南

修改 `han.source` 时要检查：

1. line/column 是否仍从 1 开始。
2. newline 处理是否影响错误定位。
3. mark/span 是否仍能防止跨 source 混用。
4. `taffish-core/lexer.lisp` 和内联 taffish scanner 是否受影响。

不要把具体语言的 token 规则写进 `han.source`。它只负责字符流。
