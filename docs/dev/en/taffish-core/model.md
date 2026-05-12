# model.lisp

`model.lisp` defines the data structures and core error condition shared across `taffish-core` stages. It is the common language between lexer, parser, binder, compiler, and emitters.

## Role

The TAFFISH compilation path is split into multiple stages. If every stage passed temporary plists or strings directly, the system would quickly lose structure. `model.lisp` fixes the objects passed between stages.

Current main structures include:

| Structure | Role |
| --- | --- |
| `taf-token` | Inline token, preserving raw text, normalized value, type, and position. |
| `taf-line` | Structured result for one TAF line. |
| `taf-context` | Host context for this compile or run. |
| `taf-program` | Static program emitted by the parser. |
| `taf-result` | Bound program emitted by the binder. |
| `taffish-error` | Core error with message, line, column, and source-string. |

## System Position

```text
model
  -> lexer
  -> parser
  -> input
  -> binder
  -> compiler
  -> emitter
```

`model.lisp` sits at the bottom of `taffish-core`. It should not depend on internal logic from lexer, parser, compiler, or emitters.

## Structure Notes

### taf-token

`taf-token` represents the smallest semantic fragment inside a line.

| Field | Meaning |
| --- | --- |
| `raw-string` | Original text, such as `::name::` or ordinary text. |
| `value` | Normalized value. Text may handle escaping; arg tokens remove outer `::`. |
| `kind` | Currently mainly `:text` or `:arg`. |
| `line` | Token start line, starting from 1. |
| `column` | Token start column, starting from 1. |

### taf-line

`taf-line` represents one TAF line.

| Field | Meaning |
| --- | --- |
| `raw-string` | Original text of this line. |
| `tokens` | Token list inside the line. For subtag lines, tokens are from inside the subtag. |
| `kind` | `:empty`, `:comment`, `:tag`, or `:code`. |
| `subkind` | `nil`, `:args`, `:run`, or `:subtag`. |
| `line-number` | Line number, starting from 1. |

### taf-context

`taf-context` represents runtime context, not user arguments.

| Field | Meaning |
| --- | --- |
| `user` | Host user. |
| `homedir` | Host home. |
| `workdir` | Working directory. |
| `loaddir` | App or TAF load directory. |
| `argv` | User command argument list. |
| `cmd` | Current command name. |
| `cpus` | CPU count and similar resource information. |
| `container` | Container config alist. |
| `extras` | Unknown context keys reserved for extension. |

### taf-program

`taf-program` is the parser output. It is still static and has not been bound to real user input.

| Field | Meaning |
| --- | --- |
| `source-string` | Original TAF source code. |
| `lines` | Normalized `taf-line` list. |
| `args-spec` | `han.args` argument specs extracted from ARGS and inline args. |
| `body` | RUN body, currently a block list grouped by subtag. |
| `metadata` | Reserved metadata. |

### taf-result

`taf-result` is the binder output and the main compiler input.

| Field | Meaning |
| --- | --- |
| `program` | Original static program. |
| `args-result` | `han.args:bind-args` result, with built-in variables. |
| `context` | Context for this run. |
| `body` | Currently isomorphic to `program.body`. |
| `diagnostics` | Argument binding diagnostics. |

## Error Model

`taffish-error` carries:

1. `message`
2. `line`
3. `column`
4. `source-string`

Core code should prefer `signal-taffish-error` for positioned errors. A small number of ordinary `error` calls still exist and can be unified later.

## Modification Guide

Be conservative when changing the model layer:

1. Before adding a field, confirm that the information is shared across stages.
2. When changing field meaning, inspect all accessor call sites.
3. Do not put temporary information from one emitter into the global model.
4. If adding token kinds or line kinds, update lexer, parser, compiler, and standard docs.

