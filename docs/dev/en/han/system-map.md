# han ASDF And Package Boundaries

`han` is TAFFISH's built-in base library. Its ASDF system name is `han`, version `0.1.0`. It is loaded as a dependency by `taffish.asd`.

## Load Order

`vendor/han/han.asd` uses `:serial t`. The current order is:

```text
test
host
source
os
path
json
args
```

This order reflects dependency direction:

1. `test` is minimal and supports tests for other han subsystems.
2. `host` isolates Lisp implementation differences.
3. `source` provides a character cursor abstraction.
4. `os` wraps files, environment, and shell on top of host.
5. `path` wraps pathname behavior on top of host.
6. `json` provides JSON needed by index/config/metadata.
7. `args` provides the TAFFISH argument system.

## Package Responsibilities

| Package | Directory | Role |
| --- | --- | --- |
| `han.test` | `test/` | Tiny test framework. |
| `han.host` | `host/` | SBCL/LispWorks and other implementation adaptation. |
| `han.source` | `source/` | Character source, mark, span, match, and consume. |
| `han.os` | `os/` | IO, environment variables, executable lookup, shell command execution. |
| `han.path` | `path/` | Pathname normalization, join, relative path, file and directory operations. |
| `han.json` | `json/` | JSON parsing, encoding, reading, and writing. |
| `han.args` | `args/` | argv lexing, argument specifications, binding, and query. |

## Dependency Boundary

`han` should not depend on TAFFISH business packages. In particular, it should not know about:

1. The TAF language.
2. taf-apps.
3. Hub index schema.
4. GitHub/Gitee organization structure.
5. Bioinformatics tool semantics.

If a capability is reused by multiple TAFFISH layers and is not business-specific, it may belong in `han`. If it only serves Hub, project, or the TAF compiler, keep it in the corresponding upper layer.

## Checkpoints Before Editing ASDF

When adding a han file, check:

1. Whether it truly belongs to the base library.
2. Whether it introduces a reverse dependency on upper TAFFISH packages.
3. Whether an API needs to be exported.
4. Whether ASDF load order is affected.
5. Whether corresponding detailed docs need to be added.

