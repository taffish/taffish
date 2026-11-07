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

In a code line, if `[[taf: ...]]` is not closed or its content is empty,
`taffish-error` is signaled. Full-line source comments (the first non-SPACE/TAB
character is `#`) are instead preserved verbatim, without scanning inline
markers or decoding bracket escapes. This includes indented comments and empty
or unclosed inline-looking text; they create no child-compilation steps.

For compiler-produced lines, `%scan-inline-parts` scans source text tokens after
the existing TAF escape decoding. Argument parts remain opaque, even if empty
or containing quotes, `[[taf:` or `]]`. Inside a call, source single/double quotes
and backslash escapes protect a closing `]]`. Markers cannot span an argument
part. Calls stay single-line and may coexist with pipes or surrounding text.
This is not a full shell parser or support for nested inline calls.

The scanner preserves command content. Prefix validation and `--compile`
insertion happen afterward using resolved text, as before. Ordinary-text bracket
decoding is retained; it is separate from deciding the call boundaries.
For old `:line/:number` inputs without origin metadata, the same scanner reads
the supplied text directly and recognizes full-line comments there. Partial or
inconsistent metadata is an error, including on comment lines. Source-backed
line classification does not change when a substituted argument contains `#`.
This does not parse shell comments following ordinary code: their inline markers
can still be scanned.

## Command Constraints

Inline taf commands must start with `taf-`. `%sure-compiled` ensures the command carries `--compile`:

| Input | Output |
| --- | --- |
| `taf-x` | `taf-x --compile` |
| `taf-x a b` | `taf-x --compile a b` |
| `taf-x --compile a b` | unchanged |

SPACE and TAB are both delimiters for the command name and the first option.
For example, `taf-x<TAB>a` becomes `taf-x --compile a`, while
`taf-x<TAB>--compile<TAB>a` is unchanged (`<TAB>` denotes one tab character).
Mixed separators are accepted. Insertion may normalize separators around the
new first option; the remaining argument text and shell expansion semantics
are preserved. This is not a shell tokenization or universal quoting pass.

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

The generated block compiles these steps in its prelude, before running its body.
This prelude runs when the generated shell is executed, not while TAF is
compiled or a project wrapper is built. Full-line source comments add no steps
to the prelude, consistent with dependency discovery by `taf check/build`.
Variables assigned in the body are not yet set at that compilation point. See
[Argument Passing](../../../standards/en/argument-passing.md) for delayed
shell-text expansion and parent/child block forwarding. A failed child compile
prints a separately shell-quoted `printf` diagnostic to stderr and exits with 1;
the diagnostic cannot evaluate the command text again. This does not make raw
parameter substitution an input-sanitization mechanism.

## Implementation Details

`*taf-apps-count*` and `*all-taf-apps*` are special variables and are dynamically bound in `emit-taffish`, avoiding cross-block pollution.

The private boundary scanner has no counter or binding side effects.
`taf check/build` reuse it on original source parts for dependency discovery,
without resolving parameters or executing an app.

## Design Boundaries And Tradeoffs

The compiler retains source tokens and resolved parts during the existing
substitution pass. The emitter therefore knows which text may delimit a call
without evaluating defaults or parameter queries a second time. See the
[compiler pipeline](compiler.md) for the internal line records.

Only boundary recognition uses this provenance. Command validation, emitter
selection, parameter substitution, child-precompilation timing and temporary
script cleanup keep their existing roles. There is no universal quoting pass
or exception for values that already look quoted: ordinary parameters,
token blocks, `*ARGV*` and command mode retain their separate contracts.

The deliberate compatibility cost is that substituted data can no longer
introduce an entire inline call on the source-backed path. Authors must put
the delimiters in source. In exchange, data containing quotes or `]]` cannot
change those boundaries. This does not make raw shell-text substitution safe
for arbitrary input, or make a raw-text child preserve a parent's argv list.

The [emitter API](../api/emitter-api.md) still accepts legacy two-field line
records. Without source provenance they must scan the supplied text; they
cannot provide the source-only boundary guarantee. The added metadata stays
internal, not a new CLI option or MCP field. Dependency scanning uses the same
boundary rule, but does not infer command names assembled from parameters.

## Modification Guide

When changing the taffish emitter, handle these carefully:

1. Temporary directory cleanup.
2. `--compile` injection.
3. Line and column for inline tokens.
4. Shell quoting.
5. Stable numbering of multiple `[[taf: ...]]` occurrences in one block.

This part is central to future advanced workflow composition and should not couple to business logic of any single app.

