# han.args Overview

`han.args` is the foundation of the TAFFISH argument system. TAF `ARGS` blocks, inline `::arg::` references, and built-in variable bindings ultimately depend on `han.args` specification parsing and binding results.

## Role

`han.args` solves three kinds of problems:

1. Parse command-line argv into tokens and segments.
2. Parse argument specification strings into structured `arg-spec` values.
3. Bind input to specs and produce `args-result`.

It does not understand TAF files and does not generate shell.

## Core Path

```text
raw argv
  -> parse-args-input
  -> args-input

spec strings
  -> parse-arg-spec
  -> parse-args-spec
  -> args-spec

args-input + args-spec + builtin bindings
  -> bind-args
  -> args-result
  -> get-arg
```

## Core Structures

| Structure | Role |
| --- | --- |
| `arg-token` | Low-level token in argv. |
| `arg-segment` | Group of token positions split by slot. |
| `args-input` | argv parsing result. |
| `arg-diagnostic` | Warning or error. |
| `arg-spec` | Single argument definition. |
| `args-spec` | Command-level argument definition collection. |
| `arg-binding` | Final binding result for one argument. |
| `args-result` | Overall binding result. |

## Argument Types

`han.args` currently supports:

| Arity | Meaning |
| --- | --- |
| `:flag` | Boolean flag; presence means true. |
| `:single` | Single-value argument. |
| `:block` | Slot block argument. |
| `:position` | Positional argument. |

## Use In TAFFISH

| TAFFISH module | Usage |
| --- | --- |
| `taffish-core/parser.lisp` | Converts ARGS blocks and inline args into `args-spec`. |
| `taffish-core/input.lisp` | Converts CLI args into `args-input`. |
| `taffish-core/binder.lisp` | Calls `bind-args` and adds built-in variables. |
| `taffish-core/compiler.lisp` | Resolves `::arg::` through `get-arg`. |
| `taf-core/project/new.lisp` | Uses `han.args` to parse `taf new` arguments. |

## Maintenance Principles

The return structures of `han.args` are shared contracts across multiple TAFFISH layers. When modifying them:

1. Keep warning/error diagnostics explainable.
2. Do not introduce TAF-specific concepts.
3. Do not read project configuration directly.
4. Do not depend on shell or container backends.
5. When changing spec syntax, update the TAF argument standard.

