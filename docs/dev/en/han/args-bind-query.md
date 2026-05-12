# han.args Binding And Query

`vendor/han/args/bind.lisp` binds `args-input` and `args-spec` into `args-result`. `query.lisp` provides `get-arg`, which reads bound values and resolves default expressions.

## Binding Phase

`bind-args` mainly does three things:

1. Collect input candidates.
2. Resolve each argument according to specs.
3. Generate diagnostics and bindings.

## Candidate Collection

`%collect-input-candidates` scans segments:

1. The default slot handles long/short options.
2. Values not consumed by options in the default slot enter the positional pool.
3. Non-default slots become block candidates.
4. Undefined options or slots produce warnings.

Single options support two forms:

```text
--name value
--name=value
```

Short options also support:

```text
-n value
-n=value
```

## Binding Status

Each final `arg-binding` has a status:

| status | Meaning |
| --- | --- |
| `:input` | Comes from user input or builtin binding. |
| `:default` | Comes from a default value. |
| `:missing` | No input and no default. |
| `:conflict` | A single value or block is provided multiple times. |

## Diagnostics

Common codes:

| code | kind | Scenario |
| --- | --- | --- |
| `:missing-option-value` | error | Missing value after an option. |
| `:undefined-option` | warning | Undefined option or slot. |
| `:missing-required` | error | Required argument missing. |
| `:conflict` | error | Single value or block provided multiple times. |
| `:unused-option` | warning | Extra positional input. |

`taffish-core/binder.lisp` turns error diagnostics into errors, but ignores `missing-required` in taf-app command mode.

## Positional Arguments

Positional specs can start from `$0` or `$1`, and must be contiguous. During binding, the smallest position becomes the base, and values are taken from the positional pool.

## Builtin Bindings

`bind-args` can receive an external builtin-table. TAFFISH passes its own built-in variable bindings. `%build-builtin-bindings` remains in `bind.lisp`, but the current main path recommends that callers construct builtins from context manually.

## get-arg

`get-arg` accepts:

1. string spec.
2. `arg-spec`.
3. integer positional index.

It first checks builtin bindings, then ordinary bindings.

If a binding value is a default expression, such as `(:query "name")` or `(:concat ...)`, `get-arg` evaluates it recursively. It detects cyclic references:

```text
a -> b -> a
```

and reports an error.

## Modification Guide

When changing bind/query, check:

1. The diagnostics strategy in `taffish-core/binder.lisp`.
2. How `compiler.lisp` resolves tokens through `get-arg`.
3. Whether block argument values remain token lists.
4. Whether default expressions may introduce cycles.
5. Whether warnings and errors clearly distinguish user errors from ignorable input.

