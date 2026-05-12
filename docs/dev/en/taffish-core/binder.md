# binder.lisp

`binder.lisp` is the semantic binding layer between parser and compiler. It combines a static `taf-program`, external input arguments, and runtime context into a `taf-result`.

## Role

The parser knows TAF source structure, but it does not know what arguments the user passed this time. The compiler needs already resolvable parameter values.

The binder is responsible for:

1. Normalizing input args.
2. Normalizing context.
3. Generating built-in variable bindings from context.
4. Calling `han.args:bind-args`.
5. Checking argument diagnostics.
6. Emitting `taf-result`.

## Built-In Variables

`%context-to-builtin-bindings` converts context into these bindings:

| Built-in | Source |
| --- | --- |
| `*USER*` | `taf-context-user` |
| `*HOMEDIR*` | `taf-context-homedir` |
| `*WORKDIR*` | `taf-context-workdir` |
| `*LOADDIR*` | `taf-context-loaddir` |
| `*ARGV*` | `taf-context-argv` |
| `*CMD*` | `taf-context-cmd` |
| `*CPUS*` | `taf-context-cpus` |
| `*CONTAINER*` | `taf-context-container` |

List context values are joined with spaces; other non-string values are converted to strings with `format`.

## taf-app Command Mode

The binder has special logic for `taf-app`:

1. If the program contains a `<taf-app:...>` block.
2. And the first element of context argv is a non-option command.
3. Then the program is considered to be in taf-app command mode.

In this mode, `:missing-required` diagnostics from `han.args` are ignored. The reason is that taf-app command mode delegates the user command to the next tag instead of requiring all ordinary arguments of the current TAF to be complete.

This is one of the key mechanisms that lets `taf-app` work as an application entry point.

## Output

`bind-taf` outputs `taf-result`:

| Field | Value |
| --- | --- |
| `program` | Input `taf-program`. |
| `args-result` | Result of `han.args:bind-args`. |
| `context` | Normalized `taf-context`. |
| `body` | Currently equals `taf-program-body`. |
| `diagnostics` | Diagnostics from `args-result`. |

## Error Handling

If `han.args` returns an error-level diagnostic, and the diagnostic is not an ignorable missing-required diagnostic under taf-app command mode, the binder signals an ordinary `error`.

If error experience is unified later, these errors can be wrapped as `taffish-error`, while preserving the original `han.args` diagnostic information.

## Modification Guide

When changing the binder, be especially careful:

1. Do not reparse TAF source.
2. Do not generate shell.
3. When adding built-ins, update the parser's builtin arg allowlist.
4. When changing taf-app command mode, check `emitter/builtins/taf-app.lisp`.
5. When changing diagnostics strategy, check CLI error output.

