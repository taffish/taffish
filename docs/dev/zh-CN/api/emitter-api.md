# Emitter API

Emitter API 用于把 TAF block 转换为 shell 片段。内置 emitter 包括 `shell`、`container`、`taffish`、`taf-app`。

## 核心对象

### `taffish.core:taf-emitter`

稳定性：半稳定。

字段：

| 字段 | 签名 | 说明 |
| --- | --- | --- |
| `name` | string | emitter 名称。 |
| `match-function` | `(tag line-number) -> parsed-info 或 nil` | 判断是否匹配 tag。 |
| `emit-function` | `(parsed-info lines taf-result) -> string-list` | 生成 shell 行。 |
| `prelude-function` | `(parsed-info lines taf-result) -> string-list` | 可选前置 shell 行。 |
| `finalize-function` | `(parsed-info shell-lines-list taf-result) -> string` | 可选最终合并。 |

## 注册 API

### `taffish.core:register-emitter`

稳定性：半稳定。

```lisp
(taffish.core:register-emitter emitter)
```

作用：把 `taf-emitter` 注册到 `*taf-emitters*`。

错误：

1. 输入不是 `taf-emitter`。
2. emitter name 重复。

### `taffish.core:defemitter`

稳定性：半稳定。

```lisp
(taffish.core:defemitter name
  :match-function ...
  :emit-function ...
  :prelude-function ...
  :finalize-function ...)
```

作用：创建并注册 emitter。

注意：注册顺序影响匹配顺序。当前没有 priority 机制。

## 发射 API

### `taffish.core:emit-block`

稳定性：稳定。

```lisp
(taffish.core:emit-block tag lines taf-result &optional emitters)
```

参数：

| 参数 | 说明 |
| --- | --- |
| `tag` | 已解析的 tag string。 |
| `lines` | resolved-line plist 列表。 |
| `taf-result` | 当前绑定结果。 |
| `emitters` | emitter 列表，默认 `*taf-emitters*`。 |

resolved-line 结构：

```lisp
(:line <line-string> :number <line-number>)
```

返回：shell string。

错误：

1. 无 emitter 匹配。
2. match/emit/prelude/finalize 缺失。
3. prelude 或 emit 没返回 string list。
4. finalize 没返回 string。

## 默认生命周期

### `taffish.core:default-prelude`

稳定性：半稳定。

生成调试注释，包括 tag、source lines、loaddir、workdir。

### `taffish.core:default-finalize`

稳定性：稳定。

把 shell line list 用 newline 合并成字符串。

## 最小 emitter 示例

```lisp
(taffish.core:defemitter demo
  :match-function
  (lambda (tag line-number)
    (when (string-equal tag "demo")
      (list :kind :demo
            :tag tag
            :line-number line-number)))
  :emit-function
  (lambda (parsed-info lines taf-result)
    (declare (ignore parsed-info taf-result))
    (mapcar (lambda (line)
              (getf line :line))
            lines)))
```

## Emitter 设计规则

1. match 函数只解析 tag，不应读取文件系统。
2. emit 函数返回 string list，不直接拼最终大字符串。
3. 需要自定义最终结构时才写 finalize。
4. 不要修改 compiler 的主流程来支持单个 tag。
5. 生成 shell 时必须考虑 quoting 和路径。

## 特殊注意

`taf-app` emitter 的 finalize 对 shell-lines-list 结构有特殊假设，它是委托型 emitter，不是普通 line-list emitter。未来如果扩展 emitter API，需要考虑这类嵌套发射场景。
