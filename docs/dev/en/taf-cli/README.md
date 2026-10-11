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

The top-level page groups project, Hub, and system commands, followed by
getting-started examples, language selection, and website/Hub/support links.
Descriptions distinguish refreshing the index from upgrading apps and mark
doctor as read-only by default. Contact links belong only to the top-level
page, not every subcommand or machine-readable output. `--version` stays a
single line containing the command name and version.

`main.lisp` establishes the resolved human-language context once before
dispatch. `i18n.lisp` owns complete built-in English/Chinese help and parser
diagnostics; `taf-core` human renderers own project, Hub, package, config,
doctor, and history messages. Command/option tokens and machine interfaces
must remain identical in every language.

## Error Handling

The executable entry point establishes an internal error boundary before
TAFFISH runtime I/O and language initialization. Errors escaping the command
handler are reported with `[TAF-ERROR]` on stderr and exit status 1. If reporting
also fails, the process still exits unsuccessfully rather than writing a fallback
message to stdout. Normal command results and existing nonzero exit semantics
remain unchanged.

This does not change `taf-core` library condition handling. Host-specific signal
behavior and its limits are documented in [han.host](../han/host.md).

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
| `i18n.lisp` | Own localized help and parser-level human diagnostics. |
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
| `taf install TARGET... --repair` | Explicit repair of existing identities; add `--dry-run` to preview instead of applying. |
| `taf install --all --repair` | Preview repair of already-installed index.latest identities; `--yes` applies. Kind and scope filters remain available. |
| `taf install --all-installed --repair` | Preview repair of all locally installed versions, including historical versions; `--yes` applies. No versions or dependencies are added. |
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
Unverified/invalid/unknown installation diagnostics are deliberately still
visible, even on otherwise unchanged items, grouped by issue type/state and
recovery policy with at most three examples per group instead of repeated skip
rows. Detailed doctor output (`--verbose`) and JSON retain full evidence.

Repair has two batch selectors. `--all --repair` checks only installed
`index.latest` identities; it skips missing latest versions rather than installing
them. `--all-installed --repair` enumerates every locally installed version,
including historical versions. It never upgrades, installs missing versions or
dependencies, or prunes. Both selectors default to preview; add `--yes` to apply.
`--json`, scope and kind filters work with either selector. The selectors cannot
be combined with each other or explicit targets. `--all-installed` requires
`--repair`. For explicit version targets, use `--dry-run` to preview and remove
it to apply. Verified targets are skipped.

Unreadable/malformed installation records and versions absent from the index
remain visible as blocked targets, not silently skipped. An unknown app kind
cannot safely be excluded by a kind filter. Private sources are not replaced
from the public index. Repair rejects `--force`, `--from` and `--prune-old`.


## Doctor Routing

`taf doctor` retains its lightweight environment checks. `taf doctor index`
checks the cached index; `taf doctor hub [APP|COMMAND...]` additionally checks
local installation evidence. Both specialized modes accept user/system,
json/verbose but reject init/shell. The core result's `:exit-code` becomes the
CLI exit status without adding an error line to JSON stdout. Error/unknown
findings exit 1; warnings alone exit 0. Default doctor's old exit behavior is
unchanged. See [diagnostics and recovery](../taf-core/system-history-doctor.md).

Doctor and maintenance human progress goes to stderr only: TTY stage/count
updates are in place, log counts are rate-limited, and JSON/MCP have no progress
text. Field alignment uses shared conservative Unicode widths; long or complex
fields use separate lines. These presentation changes do not alter machine
fields, safety classification or exit codes.

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

## Operation Status

Slow human-facing operations report their current target and stage on stderr.
TTY updates, log throttling, target-count semantics, quiet/JSON behavior and
limits are described in [command status](../taf-core/command-progress.md). These notices do not change
validation, mutation, retry or exit-code rules.
