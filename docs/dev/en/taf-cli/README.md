# taf-cli

`taf-cli` is the implementation layer for the `taf` command. It exposes project, Hub, and system capabilities from `taf-core` as user commands.

## Role

`taf` is the entry point most ordinary users and taf-app authors touch. It should provide a stable, clear, scriptable command experience.

`taf-cli` is mainly responsible for:

1. Parsing subcommands.
2. Organizing CLI help and error output.
3. Calling corresponding `taf-core` APIs.
4. Presenting results to users.

Help is part of the public CLI surface. `taf --help` should stay concise,
while `taf help <command>` and `taf <command> --help` should route users to the
same command-specific help text.

`main.lisp` establishes the human language through `taffish.i18n` before
dispatch. `i18n.lisp` owns complete built-in English/Chinese help and common
top-level diagnostics. Command and option tokens stay identical in both
languages; lower-level business errors may still use English fallback.

## System Position

```text
user
  -> taf command
  -> taf-cli
  -> taf-core
  -> taffish-core
```

## File Responsibilities

| File | Role |
| --- | --- |
| `package.lisp` | Define CLI package. |
| `i18n.lisp` | Own localized help and common human CLI diagnostics. |
| `run.lisp` | Implement subcommand dispatch and execution. |
| `main.lisp` | Provide entry function. |

## Boundary With taf-core

`taf-cli` may handle command-line presentation, but business rules should live in `taf-core`.

Examples:

| Question | Location |
| --- | --- |
| What a subcommand is named | `taf-cli` |
| How subcommand help is displayed | `taf-cli` |
| Whether `taffish.toml` is valid | `taf-core/project/check.lisp` |
| How Hub index is parsed | `taf-core/hub/info.lisp` |
| What config defaults are | `taf-core/system/config.lisp` |

## Hub Maintenance Commands

The package-maintenance command surface follows a conservative CLI pattern:

| Command | Default behavior |
| --- | --- |
| `taf install --all` | Dry-run plan for all indexed apps selected by `--kind`, `--tools`, or `--flows`. |
| `taf outdated` | Read-only comparison between local install metadata and the local index. |
| `taf upgrade` | Dry-run upgrade plan; requires `--yes` to install newer indexed versions. |
| `taf prune` | Dry-run cleanup plan; requires `--yes` to remove older local app versions. |

These commands must keep `--user` / `--system`, `--json`, kind filters, and
target parsing consistent with the corresponding `taf-core` APIs. They must
not remove shared container image caches.

Default text output is change-oriented. When every item is already current or
otherwise skipped, the command should print a short `no changes` message
instead of listing every unchanged app. JSON output remains the full
machine-readable plan and keeps current/skipped items for automation.

## Language Management

`taf config language` and `taf config language --show` provide the same
read-only status/discovery view. Supplying `en`, `zh`, `auto`, or a discovered
external locale performs a narrow config update through
`taf.core:system-config-language`. CLI parsing must reject language values
combined with `--show`, profile flags, or `--force`. No MCP mutation command is
derived from this human CLI surface.

A missing saved preference is reported as configured `auto`: human CLI output
follows a recognized host locale and falls back to English. Explicit `en` or
`zh` remains deterministic and is never overridden by host locale variables.

## Modification Guide

When changing `taf-cli`, check:

1. Whether completion needs updates.
2. Whether command examples in README need updates.
3. Whether exit codes and output remain script-friendly.
4. Whether business logic has accidentally moved into the CLI layer.
5. Whether English/Chinese help preserves the same command and option contract.
6. Whether JSON and MCP projections remain stable English machine interfaces.

Long-term, `taf-cli` command design directly affects TAFFISH user experience. It should stay stable, concise, and easy to debug.
