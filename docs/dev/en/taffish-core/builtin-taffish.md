# taffish emitter

`emitter/builtins/taffish.lisp` implements the `<taffish>` tag. It supports inline calls to other taf-apps inside TAF shell content and compiles those calls into temporary scripts first.

## Role

The `taffish` emitter is an important entry to TAFFISH composition. It lets one TAF reference another taf-app:

```taf
RUN
<taffish>
[[taf: taf-example --input x ]] | other-command
```

During shell generation, `[[taf: ...]]` is replaced by a temporary script path.

## Match Rule

It matches only when the tag is case-insensitively equal to `taffish`.

## Inline Syntax

Currently recognized:

```text
[[taf: ...]]
```

In ordinary text:

| Raw text | Meaning |
| --- | --- |
| `\[` | Ordinary `[`. |
| `\]` | Ordinary `]`. |

If `[[taf: ...]]` is not closed or its content is empty, `taffish-error` is signaled.

## Command Constraints

Inline taf commands must start with `taf-`. `%sure-compiled` ensures the command carries `--compile`:

| Input | Output |
| --- | --- |
| `taf-x` | `taf-x --compile` |
| `taf-x a b` | `taf-x --compile a b` |
| `taf-x --compile a b` | unchanged |

If the command does not start with `taf-`, `taffish-error` is signaled.

## Generation Logic

The emitter creates a temporary directory:

```sh
taffish_tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/taffish.XXXXXX") || exit 1
trap 'rm -rf "$taffish_tmpdir"' EXIT INT TERM HUP
```

Each inline taf app is compiled as:

```text
$taffish_tmpdir/step-N-taf-xxx.sh
```

Then `[[taf: ...]]` in the original line is replaced by the corresponding script path.

## Implementation Details

`*taf-apps-count*` and `*all-taf-apps*` are special variables and are dynamically bound in `emit-taffish`, avoiding cross-block pollution.

## Modification Guide

When changing the taffish emitter, handle these carefully:

1. Temporary directory cleanup.
2. `--compile` injection.
3. Line and column for inline tokens.
4. Shell quoting.
5. Stable numbering of multiple `[[taf: ...]]` occurrences in one block.

This part is central to future advanced workflow composition and should not couple to business logic of any single app.

