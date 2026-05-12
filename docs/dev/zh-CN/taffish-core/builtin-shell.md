# shell emitter

`emitter/builtins/shell.lisp` 实现最基础的 `<shell>` 标签。它把 TAF block 中的内容行直接输出为 shell。

## 作用

`shell` emitter 是 TAFFISH 的最小执行模型。它不做容器包装，不做内联 taf-app 编译，也不做命令模式委托。

## 匹配规则

只有 tag 与 `shell` 大小写不敏感相等时才匹配：

```taf
RUN
<shell>
echo hello
```

## 发射规则

emit 函数直接返回每个 resolved line 的 `:line` 字段。

换句话说，`<shell>` 下的代码在参数 token 已经被 compiler 替换后，会原样进入生成 shell。

## 系统位置

```text
compiler
  -> emit-block "shell"
  -> shell emitter
  -> default prelude + 原始 shell lines
```

## 修改指南

`shell` emitter 应保持简单。不要把 container、taf-app 或 hub 逻辑加入这里。

如果要增强 shell emitter，优先考虑是否属于通用 shell 输出契约，例如错误注释、调试信息或 source map，而不是某个生物信息工具的特殊逻辑。
