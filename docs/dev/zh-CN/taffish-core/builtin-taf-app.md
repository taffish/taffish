# taf-app emitter

`emitter/builtins/taf-app.lisp` 实现 `<taf-app:...>` 标签。它是 TAF 程序作为应用入口时的重要桥接层。

## 作用

`taf-app` emitter 解决的问题是：当一个 TAF 文件被包装成 app 后，用户输入可能不是普通参数，而是一个子命令或下游命令。此时当前 TAF 需要把命令委托给另一个 tag。

## 标签格式

基本形式：

```taf
RUN
<taf-app:shell>
echo hello
```

`taf-app:` 后面的内容会作为 `next-tag`。真正发射时，`taf-app` 会再调用：

```lisp
taffish.core:emit-block
```

把内容委托给 `next-tag` 对应的 emitter。

## 命令模式

如果 context 的 argv 第一个元素是非 option 字符串，例如：

```text
blastn ...
```

则 `taf-app` 认为这是 command mode。此时它不会使用原 block 的 lines，而是把整个 argv 拼成一行，交给 `next-tag`。

这和 `binder.lisp` 中忽略 missing-required 的逻辑配合使用：

1. binder 判断是否存在 `<taf-app:...>` block。
2. 如果 argv 是命令模式，missing-required 不再阻断。
3. taf-app emitter 把 argv 作为命令委托给 next-tag。

## finalize

`finalize-taf-app` 期望 shell-lines-list 中正好有两部分：

1. taf-app 自己的 prelude。
2. next-tag emitter 返回的 shell string。

如果结构不符合，会报错。这说明 taf-app 当前是一个较薄的委托层，而不是普通 line-list emitter。

## 修改指南

修改 taf-app 时必须同步检查：

1. `binder.lisp` 的 command mode 识别。
2. CLI 层传入 context argv 的方式。
3. 下游 next-tag 的输出结构。
4. taf-app 应用入口的用户体验。

不要让 taf-app 直接知道 hub install 或 package index 的细节。它只应该处理“应用入口如何委托执行”。
