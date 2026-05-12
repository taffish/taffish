# parser.lisp

`parser.lisp` converts the `taf-line` list emitted by the lexer into a `taf-program`. It is where TAF static semantics are established.

## Role

The parser answers:

1. Which lines belong to ARGS.
2. Which lines belong to RUN.
3. Which subtag blocks exist under RUN.
4. How ARGS are converted into `han.args` argument specs.
5. Whether inline `::arg::` references correspond to usable parameters.

The parser does not read real user input and does not generate shell.

## Normalization Entry

`%normalize-taf-lines` normalizes source entry forms:

| First effective line | Normalized result |
| --- | --- |
| `ARGS` or `RUN` | Keep original structure. |
| `<...>` | Automatically prepend `RUN`. |
| Ordinary code | Automatically prepend `RUN` and `<taffish>`. |
| Empty file | Currently signals an ordinary `error`. |

This lets simple TAF omit explicit `RUN <taffish>`, while later parser stages still see a unified structure.

## ARGS And RUN Split

`%split-args-run` splits normalized lines into:

1. `args-block`
2. `run-block`

Rules include:

1. `ARGS` may appear only once.
2. `RUN` may appear only once.
3. `ARGS` cannot appear after `RUN`.
4. New primary tags cannot appear inside a block.

## Subtag Blocks

`%normalize-block-subtags` groups lines inside a block by subtag. The approximate structure is:

```lisp
((<subtag-line> line line ...)
 (<subtag-line> line line ...))
```

Code lines must appear after a subtag. Empty subtags in RUN blocks are errors. Empty subtags in ARGS blocks are currently allowed.

## Sources Of Argument Specs

The parser collects argument specs from two places:

1. ARGS block.
2. All inline `::...::` tokens.

In an ARGS block, each subtag head becomes an argument name, and the child lines are joined into a default expression. Inline args enter `han.args` directly as argument specs.

The parser finally calls:

```lisp
han.args:parse-args-spec
han.args:parse-arg-spec
```

to obtain the unified `args-spec`.

## Dead Argument Check

`%validate-args-used` checks whether an inline arg is a "dead" argument: not settable and without a default value. Built-in variables are excluded from this check.

Built-ins include:

```text
*USER*
*HOMEDIR*
*WORKDIR*
*LOADDIR*
*ARGV*
*CMD*
*CPUS*
*CONTAINER*
```

This catches TAF files that refer to parameters impossible to provide by user input or defaults.

## Output

`parse-taf` outputs `taf-program`:

| Field | Source |
| --- | --- |
| `source-string` | Original TAF string. |
| `lines` | Normalized `taf-line` values. |
| `args-spec` | Argument specs combined from ARGS and inline args. |
| `body` | RUN block. |
| `metadata` | Currently `nil`. |

## Current Implementation State

Most parser semantic errors use `signal-taffish-error`, but a few ordinary `error` calls remain. If error experience is improved later, those ordinary errors can be gradually converted to `taffish-error` with line, column, and source-string.

## Modification Guide

Keep three boundaries when modifying the parser:

1. Do not read CLI input.
2. Do not generate shell.
3. Do not put emitter-specific semantics into the parser.

When adding TAF syntax, first decide whether it is a lexical rule, structural rule, binding rule, or emission rule. Do not put every new capability into the parser.

