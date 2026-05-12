# han.args Input Lexer

`vendor/han/args/lexer.lisp` parses raw argv into tokens and segments. It is the input structuring step before argument binding.

## Role

The lexer receives input such as:

```lisp
("cmd" "--input" "a.fa" "@run:" "blastn" "-query" "a.fa")
```

and outputs `args-input`:

1. `raw-cmd`
2. `raw-argv`
3. token vector
4. segment list
5. diagnostics

## Token Types

| Input form | kind | value | extra |
| --- | --- | --- | --- |
| `--name` | `:long-option` | `name` | nil |
| `--name=value` | `:long-option` | `name` | `value` |
| `-n` | `:short-option` | `n` | nil |
| `-n=value` | `:short-option` | `n` | `value` |
| `@slot:` | `:slot-switch` | `slot` | nil |
| `@:` | `:slot-switch` | nil | nil |
| other | `:value` | original string | nil |

Special cases produce warnings, for example:

1. A single `-`.
2. A single `--`.
3. `---abc`.
4. `@xxx` without a trailing `:`.

These warnings do not stop later binding, but they enter diagnostics.

## Segment

`parse-segments` splits token positions by slot switch:

```text
default segment
@run: segment
@: return to default segment
```

`arg-segment` stores only the slot name and token positions. It does not copy tokens directly. The binding phase uses positions to look up the token vector.

## parse-args-input

`parse-args-input` reads from `han.host:argv` by default, but raw input args can be passed explicitly.

`add-cmd` is prepended to raw input. TAFFISH uses this mechanism in `normalize-input-args` to fill the default command name.

## Modification Guide

When changing the lexer, check:

1. Whether `bind.lisp` cases over token kinds stay synchronized.
2. Whether slot syntax can still express block arguments.
3. Whether warning codes/messages are enough to locate user input issues.
4. Do not check specs in the lexer stage; that belongs to the bind stage.

