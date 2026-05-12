# han Base Library

`han` is TAFFISH's built-in base library, located at `vendor/han/`. It is not an independent business layer; it provides foundational capabilities for cross-platform behavior, parsing, paths, JSON, command-line arguments, and related utilities.

## Role

TAFFISH needs stable handling for paths, environment variables, external commands, JSON, argument specifications, and testing across systems. If these capabilities were scattered through `taffish-core` and `taf-core`, the business logic would quickly become hard to maintain.

`han` exists to centralize these common capabilities, allowing upper layers to depend on stable interfaces instead of repeatedly handling low-level details.

## System Position

```text
vendor/han
  -> taffish-core
  -> taf-core
```

`han` sits at the bottom of the TAFFISH dependency chain. It should not depend on `taffish-core` or `taf-core`. If `han` starts knowing about the TAF language or Hub concepts, the boundary has been polluted.

## Subsystems

| Subsystem | Path | Role |
| --- | --- | --- |
| `han.test` | `test/` | Small test framework or test helpers. |
| `han.host` | `host/` | Host implementation differences, arguments, and platform-specific implementation. |
| `han.source` | `source/` | Character source abstraction. |
| `han.os` | `os/` | OS capabilities such as IO, environment variables, and shell command execution. |
| `han.path` | `path/` | Path handling and normalization. |
| `han.json` | `json/` | JSON encoding and decoding. |
| `han.args` | `args/` | Command-line argument specs, lexing, binding, and query. |

## Special Position Of han.args

`han.args` is the foundation of the TAFFISH argument system. TAF `ARGS` blocks are eventually converted by the parser into argument specs that `han.args` understands. The binder then uses `han.args` to bind external input into program results.

This means:

1. Advanced semantics of TAF arguments should not be scattered into the CLI layer.
2. Rules for defaults, required arguments, flags, repetition, and related behavior should remain inside the `han.args` contract as much as possible.
3. If the return structures of `han.args` change, check `taffish-core/parser.lisp`, `taffish-core/input.lisp`, and `taffish-core/binder.lisp`.

## Role Of han.host

`han.host` isolates differences between Common Lisp implementations. The current system has implementation files for SBCL, LispWorks, and unsupported hosts. TAFFISH aims to become a stable command-line tool, so host differences must not leak into upper business logic.

If an upper module needs to branch on Lisp implementation, first consider whether that branch should move down into `han.host`.

## Modification Guide

Changes to `han` require more care than changes to upper layers because the impact surface is larger:

1. Do not introduce dependencies on TAFFISH business concepts.
2. Keep return values simple, explicit, and composable.
3. Error messages may help locate low-level problems, but should not assume the caller is necessarily `taf` or `taffish`.
4. After changing `han.args`, `han.json`, or `han.path`, inspect all direct call sites.

## Future Improvement Directions

`han` already has its own detailed documentation set. Future expansion can focus on:

1. `han.args` argument specification and binding.
2. `han.path` path rules.
3. `han.json` supported range.
4. `han.os` external command and environment-variable conventions.

## Detailed Docs

- [ASDF And Package Boundaries](system-map.md)
- [han.args Overview](args-overview.md)
- [han.args Input Lexer](args-lexer.md)
- [han.args Argument Specification](args-spec.md)
- [han.args Binding And Query](args-bind-query.md)
- [han.source Character Source](source.md)
- [han.path Path Tools](path.md)
- [han.json JSON Tools](json.md)
- [han.os OS Tools](os.md)
- [han.host Host Adaptation Layer](host.md)
- [han.test Test Tools](test.md)
