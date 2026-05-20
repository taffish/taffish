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

`hub-outdated` and `hub-upgrade` compare the newest locally installed version of
each package with the index `latest` record. Local/private installs whose
metadata says `origin_kind = local-project` are skipped rather than upgraded
from the public index.

## Kind Filtering

Batch operations accept `:tool`, `:flow`, or `:all`.

The kind is taken from install metadata when present. For older installations,
the code falls back to index metadata or checks the installed source project.

## Prune Semantics

`hub-prune` removes older local app versions and keeps the newest local version.
It deletes TAFFISH install roots and launchers, then refreshes the unversioned
command alias.

It does not remove shared container images, Podman/Docker image stores,
Apptainer caches, or SIF files. Image cache management is intentionally kept
outside local app pruning because image stores may be shared by unrelated apps
or users.

## JSON Contract

Maintenance results use the machine-readable schema:

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

Typical statuses include `current`, `outdated`, `ahead`, `missing-index`,
`local-project`, and `not-installed`.

Typical actions include `skip`, `install`, `upgrade`, `install-latest`, and
`remove-old`.

## Text Presentation Contract

The structured result is the source of truth. JSON output should preserve all
items, including `current` and skipped entries, so automation can inspect the
full decision set.

Human text output is intentionally quieter. It should display only items whose
action would change local state, and print `no changes` when all items are
skipped. This keeps bulk maintenance commands useful in shell sessions without
hiding machine-readable detail from `--json`.

## Modification Guide

When changing this layer, check:

1. Dry-run must never write files.
2. `--yes` behavior must be explicit and tested.
3. Local/private `--from` installs must not be silently upgraded from public
   index data.
4. `install.json` compatibility matters because list, which, uninstall,
   outdated, upgrade, and prune all consume it.
5. MCP may expose only read-only or dry-run planners for these operations.
