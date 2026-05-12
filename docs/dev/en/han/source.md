# han.source Character Source

`han.source` provides a position-tracked character cursor. It is the low-level input abstraction for lexers and parsers.

## Role

Writing lexers directly with string indexes easily loses line/column information and makes rollback difficult. `han.source` wraps a string as a mutable cursor and provides mark, span, peek, consume, and related operations.

The TAFFISH TAF lexer and parts of `han.args` scanning depend on similar capabilities.

## Core Structures

| Structure | Role |
| --- | --- |
| `char-source` | Contains id, string, length, index, line, and column. |
| `char-source-mark` | Saves index/line/column for a source. |
| `char-source-span` | Range from start to end in the same source. |

Each source has an independent id. Marks and spans record their source, preventing a mark from one source from being used to reset another source.

## Position Model

`source-location` returns three values:

```lisp
index, line, column
```

Line and column start from 1. When `source-next-char` reads a newline, line increases by 1 and column resets to 1; other characters increment column by 1.

## Common APIs

| API | Role |
| --- | --- |
| `make-char-source` | Create a source from a string. |
| `source-eof-p` | Whether EOF is reached. |
| `source-peek-char` | Inspect current character without advancing. |
| `source-next-char` | Read current character and advance. |
| `source-match-char-p` | Whether current character matches. |
| `source-match-string-p` | Whether the current position matches a string. |
| `source-consume-char-if` | Consume one character if it matches. |
| `source-consume-string-if` | Consume a string if it matches. |
| `source-skip-while` | Keep skipping while a predicate is true. |
| `source-read-while` | Keep reading while a predicate is true and return a string. |

## Mark And Span

`make-source-mark` saves the current position. `source-reset` can return to that position.

`make-source-span` requires start and end to come from the same source, and the end index must not be smaller than the start index. `source-slice-by-span` can use a span to extract the original string fragment.

## Modification Guide

When changing `han.source`, check:

1. Whether line/column still start from 1.
2. Whether newline handling affects error locations.
3. Whether mark/span still prevent cross-source misuse.
4. Whether `taffish-core/lexer.lisp` and the inline taffish scanner are affected.

Do not put language-specific token rules into `han.source`. It only owns character streams.

