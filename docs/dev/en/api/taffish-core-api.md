# taffish-core API

`taffish-core` is the core TAF compiler. Its public API is mainly organized around source parsing, input binding, and shell generation.

## Recommended Main Entry

### `taffish.core:taffish-to-shell`

Stability: stable.

```lisp
(taffish.core:taffish-to-shell taf-code input-args context)
```

Role: compile TAF source code, input arguments, and runtime context into a shell string.

Arguments:

| Argument | Type | Meaning |
| --- | --- | --- |
| `taf-code` | string | TAF source code. |
| `input-args` | list | Argument list such as `("cmd" "--name" "x")`. |
| `context` | alist or `taf-context` | Runtime context. |

Return: shell string.

Internal path:

```text
parse-taf -> bind-taf -> compile-taf
```

Common errors:

1. `taf-code` is not a string.
2. TAF syntax error.
3. Required parameter is missing.
4. No emitter matches a tag.

## Compilation Stage APIs

### `taffish.core:parse-taf`

Stability: stable.

```lisp
(taffish.core:parse-taf taf-code)
```

Role: parse TAF source code into a `taf-program`.

Return: `taf-program`.

Suitable for:

1. Static TAF checks.
2. Inspecting args-spec.
3. Inspecting the program body before binding.

Not suitable for: argument binding or shell generation.

### `taffish.core:normalize-input-args`

Stability: semi-stable.

```lisp
(taffish.core:normalize-input-args input-args)
```

Role: convert list input into `han.args:args-input`.

Note: TAFFISH fills a default command name `taffish`. Upper layers usually do not need to call this directly unless debugging argument input.

### `taffish.core:normalize-input-context`

Stability: stable.

```lisp
(taffish.core:normalize-input-context context)
```

Role: convert a context alist into `taf-context` and fill default container config.

Known context keys:

```text
:user :homedir :workdir :loaddir :argv :cmd :cpus :container
```

Unknown keys go into `taf-context-extras`.

### `taffish.core:bind-taf`

Stability: stable.

```lisp
(taffish.core:bind-taf taf-program input-args &optional context)
```

Role: bind `taf-program`, input arguments, and context into `taf-result`.

Return: `taf-result`.

Side effects: no filesystem side effects.

Special behavior: if the program contains `<taf-app:...>` and argv is in command mode, `missing-required` diagnostics may be ignored.

### `taffish.core:compile-taf-result`

Stability: stable.

```lisp
(taffish.core:compile-taf-result taf-result &optional emitters)
```

Role: generate a complete shell string from a bound `taf-result`.

Return: shell string containing `#!/bin/sh`.

### `taffish.core:compile-taf`

Stability: semi-stable.

```lisp
(taffish.core:compile-taf taf-result-or-program &optional emitters)
```

Role: dispatch to a compile function according to input type.

Currently only the `taf-result` path is usable. Passing a `taf-program` enters `compile-taf-program`, which is not implemented yet.

### Internal reserved: `compile-taf-program`

Stability: reserved.

Currently not exported and not implemented. Do not call it through internal package access in new code.

Reason: compiling directly from `taf-program` requires choosing default input args and context, which would introduce implicit semantics. The stable path remains:

```text
parse-taf -> bind-taf -> compile-taf-result
```

## Data Structure APIs

Stability: semi-stable.

The following structures and accessors are exported for debugging and cross-module transfer:

| Structure | Meaning |
| --- | --- |
| `taf-token` | Inline token. |
| `taf-line` | Logical line. |
| `taf-context` | Runtime context. |
| `taf-program` | Parser output. |
| `taf-result` | Binder output. |

These structure fields are currently exposed directly. Reading them is acceptable, but external code should not casually construct incomplete objects and hand them to the compiler. Prefer `parse-taf`, `normalize-input-context`, and `bind-taf` to produce valid objects.

## Error APIs

### `taffish.core:taffish-error`

Stability: stable.

Field accessors:

1. `taffish-error-message`
2. `taffish-error-line`
3. `taffish-error-column`
4. `taffish-error-source-string`

### `taffish.core:signal-taffish-error`

Stability: semi-stable.

```lisp
(taffish.core:signal-taffish-error message
  :line line
  :column column
  :source-string source-string)
```

Internal modules can use it to signal positioned errors. Note that some ordinary `error` calls still exist; the error model is not fully unified yet.

## Call Example

```lisp
(let* ((taf-code "RUN
<shell>
echo ::name::")
       (shell (taffish.core:taffish-to-shell
               taf-code
               '("demo" "--name" "Alice")
               '((:user . "alice")
                 (:workdir . "/tmp")
                 (:loaddir . "/tmp")))))
  shell)
```

## Common Misuse

1. Calling `compile-taf-program` directly.
2. Passing an unbound program to the compiler.
3. Depending on `%`-prefixed internal functions in upper-level code.
4. Manually constructing `taf-result` outside the compiler path while missing `args-result` or context.

