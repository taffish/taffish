# taf-core Hub System

The Hub system lives in `taf-core/hub/` and handles TAFFISH app indexing, query, search, install, maintenance, uninstall, and lookup.

## Role

The Hub system lifts taf-apps from "local projects" into "discoverable, installable, updatable ecosystem objects". It does not compile the TAF language itself; it builds index and install logic around already published packages, artifacts, versions, and commands.

## Core Files

| File | Role |
| --- | --- |
| `i18n.lisp` | Register Hub/package human messages and map stable plan/status values to localized presentation. |
| `update.lisp` | Update local Hub index. |
| `info.lisp` | Load index and resolve package, command, artifact, version. |
| `search.lisp` | Search index. |
| `install.lisp` | Install Hub packages. |
| `uninstall.lisp` | Uninstall packages. |
| `list.lisp` | List local installations. |
| `which.lisp` | Locate commands or install paths. |
| `upgrade.lisp` | Plan and apply outdated/install-all/upgrade/prune operations. |
| `diagnostics.lisp` | Share read-only installation/index evidence classification and safe recovery guidance. |
| `repair.lisp` | Classify explicitly requested repair targets without weakening source, identity or path checks. |

## Index Contract

`hub/info.lisp` currently expects the local index schema:

```text
taffish.index/v1
```

The index is one of the most important external contracts of the Hub system. It
connects GitHub/Gitee releases, local installation state, `taf` query behavior,
container digest/platform metadata, and declared smoke metadata.

## Version Selection And Safe Pruning

Online selection and local ordering are separate:

- An unversioned indexed install uses `packages[name].latest`. Batch install,
  outdated, and upgrade use that same target, not the largest indexed version.
- If that exact target is installed, maintenance considers its version current;
  separate validation evidence determines warnings or blocked writes.
  Otherwise a newer local version is kept; bulk maintenance never downgrades it.
- `taf-core/version.lisp` provides internal shared comparison for Hub ordering,
  aliases, maintenance, and publish's diagnostic tag ordering. Numeric components
  are integers (`a.7.10 > a.7.3`, `rc.10 > rc.2`, `r10 > r9`). A numeric core's
  final release ranks above its prereleases; build metadata does not affect
  precedence. Numeric cores may have other than three components, and natural
  numeric comparison also handles suffixes such as `rc10` and `rc2`.
- Opaque versions with matching nonnumeric structure can be naturally compared.
  Other formats have a deterministic display order but are not reliable upgrade
  or deletion evidence. Maintenance reports an error rather than guessing an
  upgrade when ordering is uncertain. Equal precedence is not equal identity.
- The unversioned command alias still follows the newest locally installed
  version under this ordering, independently of index availability or latest.

`prune` first requires an installed, valid, same-source index.latest. It verifies
the retained wrapper, frozen snapshot, and launcher without executing them. A
missing index/record/target, invalid target, or private local-project group is
skipped, not replaced with a local maximum. Among eligible entries, only
reliably older versions from the same canonical repository are removed. Unknown
or conflicting origins, newer versions, and ambiguous/equal-precedence identities
are protected. Legacy installations without the build validation manifest cannot
serve as verified retention targets or deletion candidates. Any unverified,
invalid or unknown recognized version protects the maintenance group from automatic cleanup.
Use `taf doctor hub APP --verbose` in the matching scope before choosing an
explicit exact-version `install --repair --dry-run` plan; back up local changes
and confirm the source. Repair is opt-in and never triggered by doctor. `--all --repair`
selects installed index.latest only. `--all-installed --repair` selects all local
installed versions, including historical versions. Neither selector installs
missing versions/dependencies or upgrades; verified targets are skipped. Any blocked target stops
the whole batch before writes. See [repair policy](hub-maintenance.md#explicit-repair).

`--prune-old` applies this policy only within the selected batch after successful
installation or confirmation of a valid current target. A failed installation
does not enter cleanup. Dry-run and MCP planners never delete files. Cleanup
does not remove container images and is not dependency-aware garbage collection:
an older command explicitly referenced by a Flow may still be needed. Review
the plan before using `--yes`.

## GitHub And Gitee

In the current project design, the GitHub organization is `taffish` and the Gitee organization is `taffish-org`. These are not the same name and should not be mixed in code or docs.

The Gitee mirror mainly serves access stability for users in China. The Hub system and system config layer need to support source rewrite or index URL configuration so users can have consistent `taf` behavior under different network environments.

## Relationship With System Config

Hub behavior reads system config, such as:

1. index URL.
2. source rewrite rules.
3. GitHub/Gitee host and owner.
4. User-overridden environment variables.

These defaults are mainly maintained by `taf-core/system/config.lisp`. Hub files should not hardcode mirror rules everywhere.

## Modification Guide

When changing the Hub system, check:

1. Whether index schema changes.
2. Whether local cache paths change.
3. Whether install, uninstall, list, which, outdated, upgrade, and prune remain consistent.
4. Whether GitHub/Gitee mirrors resolve correctly.
5. Whether errors help users distinguish network issues, index issues, and package issues.
6. Whether localized text remains isolated from index/install JSON, plan values,
   source URLs, and raw git/curl output.

Long-term, the Hub system needs its own documentation. That is beyond the first source-code developer manual phase, but this page should keep interface boundaries clear.
