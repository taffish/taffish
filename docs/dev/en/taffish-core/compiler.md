# compiler.lisp And main.lisp

`compiler.lisp` converts a bound `taf-result` into the final shell string. `main.lisp` provides the commonly used external entry `taffish-to-shell`.

## Role

The compiler consumes the binder's result without reparsing CLI input or TAF source. It does three things:

1. Resolve `::arg::` tokens to actual values.
2. Convert the RUN block into resolved blocks.
3. Call emitters to generate shell.

## Token Resolution

Rules for `%resolve-taf-token`:

| token kind | Result |
| --- | --- |
| `:text` | Return token value directly. |
| `:arg` | Query bound value through `han.args:get-arg`; error if missing. |

When an arg value is `nil`, it outputs an empty string.

## Line And Block Resolution

The compiler internally represents resolved lines as plists:

```lisp
(:line <line-string> :number <line-number>
 :source-line <original-taf-line> :resolved-parts <parts>)
```

Each part records `:kind`, `:token` (the original token), and resolved `:text`.
Comments and empty lines use one text part without a token. The parts are
produced in the same pass as `:line`; parameter queries are not repeated, and
the original program is not mutated. Concatenating part texts equals `:line`.

Only the `<taffish>` inline boundary scanner consumes this origin information.
Other emitters can continue reading `:line/:number`. Tag selection and parameter
formatting still use the resolved values. The extra fields are internal,
read-only metadata, not a new MCP/JSON field or a replacement for the existing
two-field `emit-block` input. See [Emitter API](../api/emitter-api.md).

Resolved block structure:

```lisp
(:tag <tag-value> :lines <resolved-lines>)
```

The tag comes from the subtag head. Lines come from content lines under the subtag.

## Emitter Calls

`%emit-resolved-body` calls:

```lisp
emit-block
```

for each resolved block. Therefore the compiler itself does not need to know concrete implementations of shell, container, taffish, or taf-app.

## Compile Entry

The currently usable main entry is:

```lisp
compile-taf-result
```

It requires input to be `taf-result`, and outputs a complete shell string starting with:

```sh
#!/bin/sh
```

`compile-taf` is a dispatch function: if the input is `taf-result`, it calls `compile-taf-result`; if the input is `taf-program`, it calls `compile-taf-program`.

## Currently Unimplemented Interface

`compile-taf-program` is explicitly unimplemented:

```text
COMPILE-TAF-PROGRAM is not implemented yet.
```

This means external callers with only `taf-program` still need to pass through `bind-taf` first. The current stable path is:

```text
parse-taf -> bind-taf -> compile-taf-result
```

## main.lisp

`taffish-to-shell` wraps the full path:

```text
taf-code + input-args + context
  -> parse-taf
  -> bind-taf
  -> compile-taf
```

This is the best high-level API for external callers.

## Modification Guide

When changing the compiler:

1. Do not put concrete tag behavior into the compiler.
2. When adding token kinds, update `%resolve-taf-token`.
3. Changing resolved-line or resolved-block structure affects all emitters.
4. If implementing `compile-taf-program`, define default args/context strategy first to avoid implicit behavior.

