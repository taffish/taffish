# han.json JSON Tools

`han.json` is a minimal portable JSON parser/writer. TAFFISH uses it to read Hub index and install metadata, and to output JSON results for list/which and related commands.

## Data Model

| JSON | Lisp representation |
| --- | --- |
| object | EQUAL hash-table |
| array | vector |
| string | string |
| number | integer or float |
| true | `t` |
| false | `nil` |
| null | `:null` |

Note: JSON false and Lisp nil are the same value, so object field reads must use the second return value of `get-json` to determine whether a key exists.

## Core APIs

| API | Role |
| --- | --- |
| `json-object` | Create an object from cons pairs. |
| `json-array` | Create a vector array. |
| `json-object-p` | Check object. |
| `json-array-p` | Check array. |
| `json-null-p` | Check `:null`. |
| `json-keys` | Return sorted keys. |
| `get-json` | Read field; second value indicates existence. |
| `set-json` | Set field. |
| `parse-json` | Parse string. |
| `read-json-file` | Read and parse file. |
| `encode-json` | Encode to string. |
| `write-json-file` | Write file. |

## Parser Capabilities

The parser supports:

1. Object.
2. Array.
3. String.
4. Number.
5. true/false/null.
6. Unicode escapes, including surrogate pairs.
7. Trailing content checks.
8. Trailing comma errors.

Parse errors use `json-error`.

## Writer Capabilities

The writer:

1. Outputs object keys in sorted order.
2. Supports indent, defaulting to 2.
3. Escapes control characters and non-ASCII characters as JSON escapes.
4. Replaces `d/D` exponents in float output with `e`.

## Use In TAFFISH

| Module | Use |
| --- | --- |
| `taf-core/hub/info.lisp` | Read index. |
| `taf-core/hub/search.lisp` | Output JSON search results. |
| `taf-core/hub/install.lisp` | Write install metadata. |
| `taf-core/hub/list.lisp` | Output list JSON. |
| `taf-core/hub/which.lisp` | Output which JSON. |

## Modification Guide

When changing `han.json`, check:

1. Whether `:null` semantics remain unchanged.
2. Whether the second return value of `get-json` remains unchanged.
3. Whether sorted object keys affect output stability.
4. Whether large Hub index parsing performance is sufficient.
5. Whether writer output is still accepted by external tools.

