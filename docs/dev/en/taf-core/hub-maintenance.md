# hub/outdated, install-all, upgrade, prune

`hub/upgrade.lisp` contains local package maintenance logic built on top of
the existing index and install metadata model.

## Role

These APIs answer four questions:

1. Which installed apps are older than the local index? (`hub-outdated`)
2. What would happen if all indexed apps were installed? (`hub-install-all`)
3. What would happen if local apps were upgraded to index latest? (`hub-upgrade`)
4. Which older local versions can be removed safely? (`hub-prune`)

The commands are intentionally conservative. `install-all`, `upgrade`, and
`prune` are dry-run by default at the CLI layer and require `--yes` to mutate
local files.

## Scope And Inputs

All maintenance APIs operate on one TAFFISH home scope:

```text
:user   -> TAFFISH user home
:system -> TAFFISH system home
```

They read:

1. `index/current.json`
2. `apps/*/*/install.json`
3. local install metadata fields such as package name, command name, version,
   origin, and kind

`hub-outdated` and `hub-upgrade` use the index `latest` record as the online
target. An already installed matching identity is current; otherwise the shared
version comparator determines local precedence without an automatic downgrade.
Local/private installs whose
metadata says `origin_kind = local-project` are skipped rather than upgraded
from the public index.

## Kind Filtering

Batch operations accept `:tool`, `:flow`, or `:all`.

The kind is taken from install metadata when present. For older installations,
the code falls back to index metadata or checks the installed source project.

`outdated` and `upgrade` apply this filter before validating installations or
comparing local versions with index latest. An excluded flow cannot block a
tool-only plan, and an excluded tool cannot block a flow-only plan. Selected
packages and `all` retain the same validation and version-order checks. MCP
planners use the same core behavior.

## Prune Semantics

`hub-prune` retains an installed, verified, same-source index `latest` and removes
only reliably older same-source versions. Private/unknown origins and newer or
incomparable versions stay protected. Missing index/latest/retained target does
not fall back to deleting around the greatest local version. If any installed
version recognized in the maintenance group is unverified, invalid or unknown, the group is protected
from automatic pruning. Apply rechecks the retained target and removal candidates.
Deletion removes TAFFISH install roots and launchers, then refreshes the
unversioned alias. Review pinned Flow dependencies before authorizing deletion;
this is not dependency-aware garbage collection.

It does not remove shared container images, Podman/Docker image stores,
Apptainer caches, or SIF files. Image cache management is intentionally kept
outside local app pruning because image stores may be shared by unrelated apps
or users.

## Installation Evidence And Recovery

`hub/diagnostics.lisp` supplies shared read-only validation to maintenance and
`taf doctor hub`. It separates four states:

| State | Evidence | Policy |
| --- | --- | --- |
| `verified` | Required local files and build-manifest checksums agree. | Eligible for further source/version safety checks. |
| `unverified` | Structure is intact but an old manifest is absent, or the launcher template is unfamiliar. | Preserve, warn, do not block ordinary batch installation or invent evidence. |
| `invalid` | A required file is missing, metadata is malformed, identity disagrees, or a checksum differs. | Block selected batch writes and exclude from automatic pruning. |
| `unknown` | Permissions, unsafe links, unsupported schema or inspection failure prevent a conclusion. | Report uncertainty, do not guess or overwrite. |

Install-all and upgrade aggregate invalid/unknown selected installations before
writing any package. Outdated remains a read-only diagnostic plan. A legacy
unverified installation can coexist with a newly installed version; `--prune-old`
still preserves the package. A version can be `current` and `unverified` at once.

Metadata paths are checked against the managed installation layout, and removal
re-reads the record before deleting files. Path mismatches are not repaired
automatically. Explicit uninstall still supports legacy records with safe paths;
it does not require a build manifest. Persisted custom system bin directories
remain supported, with launcher names checked against that directory.

For applied operations, `--yes --json` reports nested installation and removal
results as JSON objects, including inside `prune_result`. Boolean `*_p` fields
remain booleans. Dry-run results do not imply any file changes.

Use `taf doctor index --user` for the local index, or
`taf doctor hub APP --user --verbose` for installed files. Choose `--system`
for system installations. Each problem identifies its target, scope, stable
code, path, consequence and remediation. Back up intentional edits and review an
exact-version `install APP VERSION-ID --repair --dry-run` plan before authorizing
a rebuild. Repair
is not a substitute for owner/compatibility review of permission or unknown-format
problems. Private installations require review against their original local
source, not replacement from the public index.

Validation never executes the installed wrapper, fetches a container, or creates
historical manifests. Checksums establish local consistency, not authenticity,
upstream safety, or runtime readiness.

Maintenance keeps the existing install-metadata enumeration contract. Use the
dedicated doctor scan to find directories whose `install.json` cannot be read or
parsed; such unrecognized directories are not automatic deletion candidates.

## Planning Performance

`doctor hub`, `install --all`, `outdated`, and `upgrade` probe the selected
installations in batches, reusing evidence across one read-only scan rather than
starting a full independent scan for each installation. A fixed POSIX shell
script reads path attributes and directory entries;
paths are separate arguments, never executable shell fragments. The output is
NUL-framed and read as UTF-8, preserving spaces, Unicode and embedded newlines.
Snapshot traversal does not follow child symlinks. Failed or incomplete probes
cannot establish a verified installation.

Attributes and directory listings are reused only within one read-only plan.
Build-manifest hashes are still computed from the files. No persistent
"already verified" cache is written, and deletion retains its separate fresh
validation. The next command observes changed content and permissions.

Human progress goes only to stderr: stage transitions and completed/total
validation counts. An interactive stderr TTY uses in-place updates; redirected
logs use separate lines with counts rate-limited to about once per second.
Stage changes and completion may also emit a line. Updates occur at probe/check
boundaries, not on a background timer; they are not an ETA and cannot interrupt
a blocked filesystem read. Non-TTY streams and `TERM=dumb` receive no cursor
control sequences. `--json`, `:verbose nil`, and MCP calls emit no progress text.

The performance target is a few seconds for about 300 small local app snapshots
on a local disk. It is not a five-second timeout or a guarantee for every
machine: snapshot size, filesystem latency, downloading and installing changed
apps are separate costs. See the [scale tests](../../../../test/README.md).

## JSON Contract

Ordinary maintenance results (without `:repair-p t`) use the machine-readable schema:

```text
taffish.package-plan/v1
```

Each result contains:

1. operation
2. scope and home
3. kind filter
4. dry-run / yes / prune-old flags
5. summary counts
6. item-level status and action

Items also expose additive `validation` / `validations` evidence: state, issue
codes, paths and details. An absent optional value or empty issue list may be
JSON `null`; consumers must not assume every item has validation evidence.

Typical statuses include `current`, `outdated`, `ahead`, `missing-index`,
`local-project`, and `not-installed`.

Typical actions include `skip`, `install`, `upgrade`, `install-latest`, and
`remove-old`.

## Text Presentation Contract

The structured result is the source of truth. JSON output should preserve all
items, including `current` and skipped entries, so automation can inspect the
full decision set.

Human text output is intentionally quieter. It displays state changes but hides
healthy unchanged items and does not repeat skipped items after a validation
summary. Repeated issues are grouped within the selected scope by issue type,
validation state and recovery policy, with counts and at most three examples per
group. Advice is shared by policy, not repeated for every app. Package, installed
identity and issue counts describe different quantities; one identity can have
several issues. `no changes` does not suppress warnings or blockers.

`taf doctor hub --verbose` retains every inspection and its evidence; `--json`
retains all structured items and issues. Summary rendering does not truncate the
underlying result. Shared display-width helpers use conservative Unicode widths,
not language-specific padding; long or complex fields fall back to separate
label/value lines without truncating their values.

## Explicit Repair

`install --repair` is an opt-in mode, not an action performed by doctor or
ordinary installation. Examples below use user scope; use `--system` for a
system installation and the corresponding write permissions when applying:

```sh
taf install APP --repair --user --dry-run
taf install APP1 APP2 --repair --user --dry-run
taf install APP 1.4.0-r1 --repair --user --dry-run
taf install --all --repair --tools --user
taf install --all --repair --tools --user --yes
taf install --all-installed --repair --user
taf install --all-installed --repair --user --yes
```

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

The whole selected batch is preflighted read-only before any mutation. Any
blocked target prevents all writes for that batch. A rebuild requires matching
indexed source and identity, safe managed paths, recognized launchers, and a
fixed source commit. Missing legacy manifests may be replaced only by evidence
from a fresh validated rebuild, never by inventing historical checksums.
Unknown schemas, private/unknown/conflicting sources, custom launchers and
unsafe or unreadable paths are rejected, not overwritten.

Each repair uses backups, staging, validation before switching, and final
validation; a failed repair rolls back its changes and retains recovery material.
An interrupted run retains a journal and blocks blind retries. Preserve that
journal and backups for recovery review rather than deleting them to bypass the
guard. Recovery layout and operational procedures are not a public API here.
The batch is **not atomic**: a later failure stops subsequent work but does not
undo earlier successful repairs. Repair and normal install/uninstall/prune share
cooperative home/bin write locks without changing deletion policy. These safeguards
do not promise crash durability, automatic crash recovery, zero downtime or lock
cooperation from older clients; avoid concurrent writes from them.

Core `hub-install`, `hub-install-many`, and `hub-install-all` expose optional
`:repair-p` (default `nil`). Repair returns `taffish.repair-plan/v1`; ordinary
calls keep their existing result contracts. There is no new MCP repair tool,
argument or execution route. Existing MCP write capabilities are unchanged;
the maintenance planners remain dry-run.

The repair JSON `selection` is `index-latest`, `installed-all-versions`, or
`explicit`. Core `hub-install-all` accepts optional `:all-installed-p nil`,
only with `:repair-p t`; no existing argument or result field is removed.

## Modification Guide

When changing this layer, check:

1. Dry-run must never write files.
2. `--yes` behavior must be explicit and tested.
3. Local/private `--from` installs must not be silently upgraded from public
   index data.
4. `install.json` compatibility matters because list, which, uninstall,
   outdated, upgrade, and prune all consume it.
5. Existing MCP maintenance planners remain read-only/dry-run; no repair entry is exposed, and existing write tools are unchanged.

## Operation Status

Slow human-facing operations report their current target and stage on stderr.
TTY updates, log throttling, target-count semantics, quiet/JSON behavior and
limits are described in [command status](command-progress.md). These notices do not change
validation, mutation, retry or exit-code rules.
