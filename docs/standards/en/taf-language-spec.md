# TAF Language Specification Draft

This page records the TAF language draft. It is more concrete than [TAF Language Contract](taf-language-contract.md), but it still follows the current reference implementation.

## Specification Status

| Scope | Status | Notes |
| --- | --- | --- |
| line types, `ARGS`/`RUN`, subtags, parameter tokens | Draft v0.1 stable | implemented by lexer/parser/binder/compiler together. |
| embedded `han.args` specs | Draft v0.1 stable | TAF relies on `han.args` for concrete argument semantics. |
| `<shell>` and container tags | Draft v0.1 stable | main execution model for current taf-apps. |
| `<taffish>` inline composition syntax | Experimental | implementation exists, but full language boundary needs Hub/flow cases. |
| `taf-app` command mode | Experimental | usable now; user-visible semantics may still be refined. |

## File Model

A TAF file is a text file. The current lexer supports LF, CRLF, and CR line endings. The compiler converts TAF source into shell; runtime behavior is determined by emitters matched by tags.

A TAF file is parsed into:

1. argument specifications.
2. one or more run blocks.
3. compilation context.
4. bound argument result.

## Line Types

The lexer classifies each line:

| Type | Recognition rule | Notes |
| --- | --- | --- |
| blank | empty after removing spaces and tabs | may be preserved in blocks. |
| comment | starts with `#` after removing spaces and tabs | may be preserved in blocks. |
| `ARGS` main tag | equals `ARGS` after removing spaces and tabs | starts argument definition. |
| `RUN` main tag | equals `RUN` after removing spaces and tabs | starts runtime section. |
| subtag | looks like `<...>` after trimming spaces/tabs | selects emitter or defines argument. |
| plain code | anything else | handled by current block or subtag. |

Main tags can only be `ARGS` or `RUN`. Subtag content may contain text tokens and parameter tokens.

## File Normalization

For simple TAF files, the parser normalizes:

1. If the first effective line is a subtag, prepend `RUN`.
2. If the first effective line is plain code, prepend `RUN` and `<taffish>`.
3. Empty files cannot compile.

Example:

```taf
echo hello
```

is equivalent to:

```taf
RUN
<taffish>
echo hello
```

This is part of language ergonomics, but complex taf-apps should prefer explicit structure.

## ARGS Block

`ARGS` defines argument specifications:

```taf
ARGS
<(--/-n)name>
World

<!(--/-i)input>
```

Inside `ARGS`:

1. Each subtag header is a `han.args` argument spec.
2. Plain code below a subtag becomes the default value.
3. `::arg::` tokens inside defaults become `@{arg}` for `han.args` default-expression handling.
4. `ARGS` subtag headers cannot contain `::...::` parameter tokens.
5. `ARGS` can be empty, but dead-argument checks still apply.

Complete argument semantics are defined by `han.args`. TAF extracts and passes the specs.

## RUN Block

`RUN` describes execution logic:

```taf
RUN
<shell>
echo hello

<container:ghcr.io/taffish/demo:0.1.0-r1>
demo --help
```

Inside `RUN`:

1. Each subtag starts a runtime block.
2. Subtag header selects the emitter.
3. Plain code below a subtag is emitter input.
4. Blank lines and comments can enter the block.
5. Non-empty subtags must have content; empty runtime subtags are errors.

A file can contain at most one `ARGS` block and one `RUN` block. `ARGS` must appear before `RUN`.

## Parameter Tokens

TAF uses `::...::` for parameter tokens:

```taf
echo "sample: ::sample::"
```

Lexer rules:

1. `::` starts the token and the next unescaped `::` closes it.
2. Unclosed parameter tokens are errors.
3. Token content is parsed by `han.args:parse-arg-spec`.
4. Parameter tokens keep line and column for diagnostics.

TAF-level escapes:

| Syntax | Value |
| --- | --- |
| `\:` | `:` |
| `\<` | `<` |
| `\#` | `#` |
| `\\` | `\` |

Other backslash sequences are preserved as ordinary text.

## Built-In Parameters

These names are provided by context and may be used without `ARGS` declarations:

| Parameter | Source |
| --- | --- |
| `*USER*` | `taf-context-user` or binding system. |
| `*HOMEDIR*` | `taf-context-homedir` or binding system. |
| `*WORKDIR*` | `taf-context-workdir` or binding system. |
| `*LOADDIR*` | `taf-context-loaddir`. |
| `*ARGV*` | `taf-context-argv`. |
| `*CMD*` | `taf-context-cmd`. |
| `*CPUS*` | `taf-context-cpus`. |
| `*CONTAINER*` | `taf-context-container`. |

These names belong to the TAFFISH reserved namespace. Normal parameters should not use `*...*` naming.

## Binding And Errors

Compilation flow should remain:

```text
lex-taf -> parse-taf -> bind-taf -> compile-taf-result
```

Responsibility boundaries:

1. lexer classifies lines, tokenizes, and records location.
2. parser builds structure, extracts argument specs, and performs static checks.
3. binder binds real input to argument specs.
4. compiler performs substitution and emitter calls.
5. emitter implements specific tag semantics.

Parser should not read real CLI arguments directly, and compiler should not reinterpret `ARGS`.

## Subtags And Emitters

Subtag headers are matched by the emitter registry. Built-in tags include:

| Tag | Semantics |
| --- | --- |
| `<shell>` | output shell lines directly. |
| `<taffish>` | TAFFISH inline/composition execution. |
| `<taf-app:...>` | taf-app wrapper mode, delegated to following tag. |
| `<container:IMAGE>` | select Docker/Podman/Apptainer by availability. |
| `<docker:IMAGE>` | require Docker. |
| `<podman:IMAGE>` | require Podman. |
| `<apptainer:IMAGE>` | require Apptainer. |
| `<docker/podman:IMAGE>` | choose an available backend from the listed candidates. |

Container tags may pass runtime arguments after `$`. Legacy `$ARGS` applies to
all selected backends. Structured `$@[backend: ARGS]` blocks apply args only to
matching backends:

```taf
<container:IMAGE$@[all: --network host][docker: --gpus all][apptainer: --nv]>
```

Structured targets are `all`, `container` as an alias for `all`, `docker`,
`podman`, `apptainer`, and `/` combinations such as `docker/podman`. Runtime
argument selection happens after backend selection, so a generic
`<container:...>` tag may compile to different final run args when a backend is
forced by context or `TAFFISH_CONTAINER_BACKEND`.

Unknown tags are handled by the emitter registry and may error.

## Unstable Areas

Still draft:

1. Full `<taffish>` composition syntax.
2. Formal relationship between `[[taf:...]]` flow dependency references and language core.
3. User-visible semantics of `taf-app` command mode.
4. Whether dynamic parameter tokens in subtag headers should be supported long-term.
5. Cross-platform shell compatibility boundary.
