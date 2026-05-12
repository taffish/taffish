# han.args 绑定与查询

`vendor/han/args/bind.lisp` 把 `args-input` 和 `args-spec` 绑定为 `args-result`。`query.lisp` 提供 `get-arg`，用于读取绑定值并解析默认表达式。

## 绑定阶段

`bind-args` 主要分三步：

1. 收集输入候选。
2. 按 spec resolve 每个参数。
3. 生成 diagnostics 和 bindings。

## 候选收集

`%collect-input-candidates` 扫描 segments：

1. 默认 slot 处理 long/short options。
2. 默认 slot 中未被 option 消费的 value 进入 positional pool。
3. 非默认 slot 作为 block candidate。
4. 未定义 option 或 slot 产生 warning。

single option 支持两种输入：

```text
--name value
--name=value
```

short option 同样支持：

```text
-n value
-n=value
```

## binding status

最终每个 `arg-binding` 都有 status：

| status | 含义 |
| --- | --- |
| `:input` | 来自用户输入或 builtin。 |
| `:default` | 来自默认值。 |
| `:missing` | 没有输入也没有默认值。 |
| `:conflict` | 单值或 block 被多次提供。 |

## diagnostics

常见 code：

| code | kind | 场景 |
| --- | --- | --- |
| `:missing-option-value` | error | option 后缺少值。 |
| `:undefined-option` | warning | 未定义 option 或 slot。 |
| `:missing-required` | error | required 参数缺失。 |
| `:conflict` | error | 单值或 block 多次提供。 |
| `:unused-option` | warning | 多余 positional input。 |

`taffish-core/binder.lisp` 会把 error diagnostic 变成错误，但会在 taf-app command mode 下忽略 missing-required。

## position 参数

positional spec 可以从 `$0` 或 `$1` 开始，必须连续。绑定时根据最小 position 作为 base，从 positional pool 中取值。

## builtin bindings

`bind-args` 可以接收外部 builtin-table。TAFFISH 会传入自己的内置变量绑定。`bind.lisp` 中保留了 `%build-builtin-bindings`，但当前主路径建议由调用者根据 context 手动构造 builtin。

## get-arg

`get-arg` 接收：

1. string spec。
2. `arg-spec`。
3. integer positional index。

它先查 builtin bindings，再查普通 bindings。

如果 binding value 是 default expression，例如 `(:query "name")` 或 `(:concat ...)`，`get-arg` 会递归求值。它会检测循环引用：

```text
a -> b -> a
```

并报错。

## 修改指南

修改 bind/query 时要检查：

1. `taffish-core/binder.lisp` 的 diagnostics 策略。
2. `compiler.lisp` 通过 `get-arg` 解析 token 的行为。
3. block 参数值是否仍是 token list。
4. default expression 是否可能产生循环。
5. warning 和 error 是否足够区分用户错误与可忽略输入。
