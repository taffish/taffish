# taffish-core API

`taffish-core` 是 TAF 编译器核心。它的公开 API 主要围绕“源码解析、输入绑定、生成 shell”展开。

## 推荐主入口

### `taffish.core:taffish-to-shell`

稳定性：稳定。

```lisp
(taffish.core:taffish-to-shell taf-code input-args context)
```

作用：把 TAF 源码、输入参数和运行上下文编译成 shell 字符串。

参数：

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| `taf-code` | string | TAF 源码。 |
| `input-args` | list | 类似 `("cmd" "--name" "x")` 的参数列表。 |
| `context` | alist 或 `taf-context` | 运行上下文。 |

返回：shell string。

内部链路：

```text
parse-taf -> bind-taf -> compile-taf
```

常见错误：

1. `taf-code` 不是 string。
2. TAF 语法错误。
3. required 参数缺失。
4. emitter 无法匹配 tag。

## 编译阶段 API

### `taffish.core:parse-taf`

稳定性：稳定。

```lisp
(taffish.core:parse-taf taf-code)
```

作用：把 TAF 源码解析为 `taf-program`。

返回：`taf-program`。

适合场景：

1. 静态检查 TAF。
2. 查看 args-spec。
3. 在 bind 前检查 program body。

不适合场景：不要用它执行参数绑定或生成 shell。

### `taffish.core:normalize-input-args`

稳定性：半稳定。

```lisp
(taffish.core:normalize-input-args input-args)
```

作用：把 list 输入转换为 `han.args:args-input`。

注意：TAFFISH 会补默认 command 名 `taffish`。上层通常不需要直接调用它，除非要单独调试参数输入。

### `taffish.core:normalize-input-context`

稳定性：稳定。

```lisp
(taffish.core:normalize-input-context context)
```

作用：把 context alist 转换为 `taf-context`，并补默认 container config。

已知 context key：

```text
:user :homedir :workdir :loaddir :argv :cmd :cpus :container
```

未知 key 会进入 `taf-context-extras`。

### `taffish.core:bind-taf`

稳定性：稳定。

```lisp
(taffish.core:bind-taf taf-program input-args &optional context)
```

作用：把 `taf-program`、输入参数和上下文绑定为 `taf-result`。

返回：`taf-result`。

副作用：无文件系统副作用。

特殊行为：如果 program 中存在 `<taf-app:...>`，且 argv 是 command mode，`missing-required` 诊断可能被忽略。

### `taffish.core:compile-taf-result`

稳定性：稳定。

```lisp
(taffish.core:compile-taf-result taf-result &optional emitters)
```

作用：从已绑定 `taf-result` 生成完整 shell 字符串。

返回：shell string，包含 `#!/bin/sh`。

### `taffish.core:compile-taf`

稳定性：半稳定。

```lisp
(taffish.core:compile-taf taf-result-or-program &optional emitters)
```

作用：根据输入类型分发到编译函数。

当前只有 `taf-result` 路径可用。传入 `taf-program` 会进入 `compile-taf-program`，但该接口尚未实现。

### 内部保留：`compile-taf-program`

稳定性：保留。

当前不导出且未实现。不要在新代码中通过内部 package 访问它。

原因：从 `taf-program` 直接编译需要决定默认 input args 和 context，这会引入隐式语义。当前稳定链路仍是：

```text
parse-taf -> bind-taf -> compile-taf-result
```

## 数据结构 API

稳定性：半稳定。

以下结构和 accessor 已导出，供调试和跨模块传递：

| 结构 | 说明 |
| --- | --- |
| `taf-token` | 行内 token。 |
| `taf-line` | 逻辑行。 |
| `taf-context` | 运行上下文。 |
| `taf-program` | parser 输出。 |
| `taf-result` | binder 输出。 |

这些结构字段目前直接暴露。可以读，但不要在外部随意构造不完整对象再交给 compiler。优先使用 `parse-taf`、`normalize-input-context`、`bind-taf` 生成合法对象。

## 错误 API

### `taffish.core:taffish-error`

稳定性：稳定。

字段 accessor：

1. `taffish-error-message`
2. `taffish-error-line`
3. `taffish-error-column`
4. `taffish-error-source-string`

### `taffish.core:signal-taffish-error`

稳定性：半稳定。

```lisp
(taffish.core:signal-taffish-error message
  :line line
  :column column
  :source-string source-string)
```

内部模块可用它抛出带位置错误。注意当前仍有部分普通 `error`，错误模型尚未完全统一。

## 调用示例

```lisp
(let* ((taf-code "RUN
<shell>
echo ::name::")
       (shell (taffish.core:taffish-to-shell
               taf-code
               '("demo" "--name" "Alice")
               '((:user . "alice")
                 (:workdir . "/tmp")
                 (:loaddir . "/tmp")))))
  shell)
```

## 常见误用

1. 直接调用 `compile-taf-program`。
2. 传入未经过 `bind-taf` 的 program 给 compiler。
3. 在上层代码依赖 `%` 开头内部函数。
4. 在外部手写 `taf-result`，但缺少 `args-result` 或 context。
