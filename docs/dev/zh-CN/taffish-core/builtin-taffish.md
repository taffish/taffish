# taffish emitter

`emitter/builtins/taffish.lisp` 实现 `<taffish>` 标签。它支持在 TAF 的 shell 内容中内联调用其他 taf-app，并把这些调用先编译成临时脚本。

## 作用

`taffish` emitter 是 TAFFISH 组合能力的重要入口。它让一个 TAF 可以引用另一个 taf-app：

```taf
RUN
<taffish>
[[taf: taf-example --input x ]] | other-command
```

生成 shell 时，`[[taf: ...]]` 会被替换成临时脚本路径。

## 匹配规则

只有 tag 与 `taffish` 大小写不敏感相等时匹配。

## 内联语法

当前识别：

```text
[[taf: ...]]
```

在普通文本中可以用：

| 原始文本 | 含义 |
| --- | --- |
| `\[` | 普通 `[` |
| `\]` | 普通 `]` |

如果 `[[taf: ...]]` 没有闭合，或者内部为空，会抛 `taffish-error`。

## 命令约束

内联 taf 命令必须以 `taf-` 开头。`%sure-compiled` 会确保命令带有 `--compile`：

| 输入 | 输出 |
| --- | --- |
| `taf-x` | `taf-x --compile` |
| `taf-x a b` | `taf-x --compile a b` |
| `taf-x --compile a b` | 保持不变 |

如果命令不是 `taf-` 开头，会抛 `taffish-error`。

## 生成逻辑

emitter 会生成临时目录：

```sh
taffish_tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/taffish.XXXXXX") || exit 1
trap 'rm -rf "$taffish_tmpdir"' EXIT INT TERM HUP
```

每个内联 taf app 会被编译为：

```text
$taffish_tmpdir/step-N-taf-xxx.sh
```

然后原始行中的 `[[taf: ...]]` 会替换成对应脚本路径。

## 实现细节

`*taf-apps-count*` 和 `*all-taf-apps*` 是 special variable，并在 `emit-taffish` 中动态绑定，避免不同 block 之间互相污染。

## 修改指南

修改 taffish emitter 时要谨慎处理：

1. 临时目录清理。
2. `--compile` 注入逻辑。
3. inline token 的 line 和 column。
4. shell quoting。
5. 多个 `[[taf: ...]]` 在同一 block 中的编号稳定性。

这部分是未来高级 workflow 组合的核心，不应和单个 app 的业务逻辑耦合。
