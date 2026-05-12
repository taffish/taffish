# lexer.lisp

`lexer.lisp` converts a TAF source string into a list of `taf-line` values. It is the first module in the compilation path that understands TAF text structure.

## Role

The lexer is responsible only for lexical recognition:

1. Read logical lines.
2. Classify line type.
3. Recognize inline `::arg::` tokens.
4. Handle a small set of TAF escapes.
5. Record line and column.

It does not own argument semantics, RUN/ARGS grouping, default value parsing, or shell generation.

## Line Reading

`%read-taf-line` supports three newline styles:

1. LF
2. CRLF
3. CR

This lets TAF files be read under different system newline styles.

## Line Classification

`%line-kind-and-subkind` classifies a trimmed line:

| Form | kind | subkind |
| --- | --- | --- |
| Empty line | `:empty` | `nil` |
| `# ...` | `:comment` | `nil` |
| `ARGS` | `:tag` | `:args` |
| `RUN` | `:tag` | `:run` |
| `<...>` | `:tag` | `:subtag` |
| Other | `:code` | `nil` |

`ARGS` and `RUN` must match exactly after trimming. `<...>` is a subtag only when the trimmed line starts with `<` and ends with `>`.

## Token Rules

The lexer currently produces two token kinds:

| kind | Meaning |
| --- | --- |
| `:text` | Ordinary text. |
| `:arg` | Parameter reference of the form `::name::`. |

For ordinary code lines, the lexer scans the full line. For subtag lines, it scans only the content inside angle brackets, and sets column to the content position in the original line.

## Escape Rules

The TAF lexer only consumes these escapes:

| Raw text | token value |
| --- | --- |
| `\:` | `:` |
| `\<` | `<` |
| `\#` | `#` |
| `\\` | `\` |

Other backslash sequences remain ordinary text. This rule is important because TAF eventually outputs shell; it must not casually consume backslashes needed by shell itself.

## Error Cases

The lexer signals `taffish-error` in these situations:

1. `::arg` is not closed.
2. Subtag line structure is invalid.

`lex-taf` itself requires a string input; otherwise it signals an ordinary `error`.

## Maintenance Invariants

1. The lexer does not perform shell word splitting.
2. The lexer does not parse ARGS argument specs.
3. The lexer does not decide whether parameters exist.
4. The lexer should preserve original text and position as much as possible.
5. Lexer output should be enough for the parser to continue without rereading raw source.

## Modification Guide

If adding a token type, such as a future interpolation syntax, also check:

1. Token kind notes in `model.lisp`.
2. Inline argument extraction in `parser.lisp`.
3. `%resolve-taf-token` in `compiler.lisp`.
4. TAF language contract docs.

Changing escape rules requires extra caution because it affects shell output of existing taf-apps.

