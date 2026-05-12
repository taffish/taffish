# taf-app emitter

`emitter/builtins/taf-app.lisp` implements the `<taf-app:...>` tag. It is an important bridge layer when a TAF program acts as an application entry point.

## Role

The `taf-app` emitter solves this problem: after a TAF file is packaged as an app, user input may be a subcommand or downstream command instead of ordinary parameters. In that case, the current TAF needs to delegate the command to another tag.

## Tag Format

Basic form:

```taf
RUN
<taf-app:shell>
echo hello
```

The content after `taf-app:` is treated as `next-tag`. During actual emission, `taf-app` calls:

```lisp
taffish.core:emit-block
```

again, delegating content to the emitter corresponding to `next-tag`.

## Command Mode

If the first element of context argv is a non-option string, for example:

```text
blastn ...
```

then `taf-app` treats it as command mode. In this mode it does not use the original block lines; instead, it joins the full argv into one line and delegates that line to `next-tag`.

This works with the missing-required ignore logic in `binder.lisp`:

1. The binder checks whether a `<taf-app:...>` block exists.
2. If argv is in command mode, missing-required no longer blocks compilation.
3. The taf-app emitter delegates argv as a command to next-tag.

## finalize

`finalize-taf-app` expects `shell-lines-list` to contain exactly two parts:

1. taf-app's own prelude.
2. The shell string returned by the next-tag emitter.

If the structure does not match, it reports an error. This means taf-app is currently a thin delegation layer, not a normal line-list emitter.

## Modification Guide

When changing taf-app, also check:

1. Command mode detection in `binder.lisp`.
2. How the CLI layer passes context argv.
3. Output structure of downstream next-tag emitters.
4. User experience of taf-app application entry.

Do not let taf-app directly know Hub install or package index details. It should only handle "how the application entry delegates execution".

