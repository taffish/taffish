# han.args Argument Specification

`vendor/han/args/spec.lisp` parses compact spec strings into `arg-spec` values and then merges them into `args-spec`.

## Role

Argument specs describe which arguments a command accepts, how each argument is entered, whether it is required, whether it is hidden, and whether it has a default value.

TAF `ARGS` blocks are eventually converted into these specs as well.

## Basic Spec Syntax

The overall form can be understood as:

```text
[prefix] [(entries)] name [? | =default]
```

Common examples:

| spec | Meaning |
| --- | --- |
| `(--/-n)name=World` | Long/short option with default value `World`. |
| `!(--/-i)input` | Required single option. |
| `(--/-v)verbose?` | Boolean flag. |
| `(@:)run` | Block/slot argument. |
| `$1` | Positional argument. |

## Prefix

| prefix | Meaning |
| --- | --- |
| `!` | Required. |
| `%` | Hidden. |

Flags are always optional. Even if `!` is written, a flag is normalized to not required.

## Entry

Entries can be:

| entry | kind |
| --- | --- |
| `--input` | long |
| `-i` | short |
| `@run:` | slot |

`--` is automatically expanded to `--<name>`. `-` is automatically expanded to `-<first letter of name>`. `@:` is automatically expanded to `@<name>:`.

Long/short entries and slot entries cannot be set at the same time. A slot entry makes the arity `:block`.

## Default Expressions

A default can be a plain string or a reference to another argument:

| Form | Structure |
| --- | --- |
| `abc` | `"abc"` |
| `@name` | `(:query "name")` |
| `@{name}` | `(:query "name")` |
| `prefix-@name` | `(:concat "prefix-" (:query "name"))` |

Supported default escapes:

| Raw | Value |
| --- | --- |
| `\@` | `@` |
| `\\` | `\` |
| `\{` | `{` |
| `\}` | `}` |

## args-spec Validation

`parse-args-spec` places multiple `arg-spec` values into a hash table and validates them:

1. Specs with the same name are merged.
2. Long/short/slot entries cannot be reused by different arguments.
3. Positional specs must start from `$0` or `$1`.
4. Positional specs must be contiguous.

## Modification Guide

When changing spec syntax, also check:

1. How `taffish-core/parser.lisp` constructs spec strings.
2. Whether `bind.lisp` understands the new arity.
3. Whether `query.lisp` can resolve the new default expression.
4. Whether argument docs and the TAF standard need updates.

Do not read actual user argv in the spec layer. The spec layer defines "what is allowed", not "what was entered this time".

