# TAFFISH Install Metadata Specification

This page defines `taffish.install/v1`, the `install.json` written after app installation.

## Specification Status

| Scope | Status | Notes |
| --- | --- | --- |
| `install.json` location | Draft v0.1 stable | `list`, `which`, `uninstall`, `outdated`, `upgrade`, and `prune` depend on this layout. |
| Core fields | Draft v0.1 stable | Removing or renaming them requires a migration strategy. |
| Command alias refresh | Draft v0.1 stable | Multi-version installation depends on this rule. |
| Source commit reproduction | Draft v0.1 semi-stable | When the index provides `source.commit`, install verifies the checked source commit before building. |
| Package maintenance plan | Draft v0.1 semi-stable | `outdated`, `upgrade`, `install --all`, and `prune` use local metadata plus the local index. |

## File Location

Install metadata is located at:

```text
<home>/apps/<package-name>/<version-id>/install.json
```

The actual cloned or copied taf-app source is stored under:

```text
<home>/apps/<package-name>/<version-id>/source/
```

## Schema

Current schema:

```json
{
  "schema_version": "taffish.install/v1"
}
```

When reading install metadata, consumers currently depend mostly on field presence. Future implementations should check schema more strictly.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | string | Must be `taffish.install/v1`. |
| `installed_at` | string | UTC time, formatted as `YYYY-MM-DDTHH:MM:SSZ`. |
| `scope` | string | `user` or `system`. |
| `name` | string | Package name. |
| `kind` | string/null | App kind, usually `tool` or `flow`. New installs should write it; readers should tolerate older metadata without it. |
| `version_id` | string | `<version>-r<release>`. |
| `artifact_name` | string | Versioned artifact command name. |
| `command_name` | string/null | Unversioned command alias name. |
| `command_file` | string | Actual built command wrapper path. |
| `launcher_file` | string | Versioned launcher path. |
| `command_launcher_file` | string/null | Unversioned alias launcher path. |
| `bin_dir` | string | Directory containing launchers. |
| `install_root` | string | Installation root directory. |
| `source_dir` | string | Source directory. |
| `repository_url` | string/null | Canonical repository URL. |
| `source_url` | string/null | Source URL recorded in the index. |
| `resolved_source_url` | string/null | URL after source rewrite. |
| `source_ref` | string/null | Ref used for clone/copy. |
| `source_commit` | string/null | Commit recorded in the index. |
| `source_commit_actual` | string/null | Actual Git `HEAD` commit observed during install verification. |
| `source_commit_verified` | boolean | True when `source_commit` was present and matched a clean source worktree. |
| `origin_kind` | string/null | Install origin category, for example `hub-index` or `local-project`. |
| `origin` | string/null | Origin value: repository URL for Hub installs, project root path for local project installs. |
| `origin_display` | string/null | Human-readable origin string, for example `[local-project] /path/to/app`. |

## Source Commit Verification

If an index version record contains `source.commit`, `taf install` must verify
the resolved source before calling `project-build`:

1. Resolve `source_url` through source rewrite.
2. Clone or copy the source into the install transaction.
3. Read the Git `HEAD` commit from the resolved source.
4. Require it to match `source_commit`.
5. Require the checked source worktree to be clean.
6. Abort installation on mismatch or dirty source.

This rule lets mirrors and source rewrite preserve the canonical index identity:
the URL used for access may change, but the source commit consumed by the
installer must remain the same. If `source_commit` is absent, install falls back
to the older ref/tag based behavior.

## Launcher Contract

The installer writes two launcher layers:

1. Versioned launcher: `<artifact_name>`.
2. Command alias launcher: `<command_name>`, meaningful when the command name differs from the artifact name.

Launchers are POSIX shell scripts that set:

```sh
TAF_LAUNCHER_NAME=<launcher-name>
TAF_LAUNCHER_ARTIFACT=<artifact-name>
```

Then they execute the built `command_file`:

```sh
exec <command_file> "$@"
```

`TAF_LAUNCHER_NAME` lets the wrapper know the command name actually invoked by the user. `TAF_LAUNCHER_ARTIFACT` preserves the exact versioned artifact.

## Command Alias Refresh

When multiple versions of the same command are installed, the unversioned alias should point to the newest version id.

Refresh rules:

1. Scan all install metadata in the same home.
2. Consider only records whose command name and bin dir match and whose `command_file` exists.
3. Select the newest version by version id ordering.
4. Write or update the alias launcher.
5. If no candidate remains, remove the alias launcher.

## Package Maintenance Behavior

`taf outdated`, `taf upgrade`, `taf install --all`, and `taf prune` consume the
same install metadata.

Rules:

1. The local index defines the public latest version.
2. The newest local version is selected by version-id ordering.
3. `origin_kind = local-project` means the install is local/private and should
   not be automatically upgraded from the public index.
4. `kind` may be used for batch filters; readers must fall back to index or
   source metadata when older `install.json` files lack the field.
5. `taf prune` removes old TAFFISH install roots and launchers, but must not
   remove shared Docker/Podman/Apptainer images, caches, or SIF files.

Machine-readable maintenance output uses:

```text
taffish.package-plan/v1
```

JSON package plans keep the full item list, including current and skipped
items. Human text output may suppress skipped items and report `no changes`
when no local state change is planned.

## Uninstall Behavior

`taf uninstall` should use `install.json` to locate:

1. Install root.
2. Versioned launcher.
3. Command alias launcher.
4. Command file.

During uninstall:

1. Remove the versioned launcher.
2. If the command alias launcher is owned by the current install record, remove or refresh it.
3. Remove the install root.
4. Keep container images and image cache.

If no matching install is found and force is not specified, uninstall should report an error. With force, it may treat the item as skipped.

## Compatibility Requirements

Install metadata is local persistent state. Adding future fields is compatible; removing or renaming fields requires a migration strategy.

At minimum, the following fields should remain readable long-term:

1. `name`
2. `version_id`
3. `artifact_name`
4. `command_name`
5. `command_file`
6. `launcher_file`
7. `command_launcher_file`
8. `bin_dir`
9. `install_root`
10. `source_dir`
11. `origin_kind`
12. `origin`
13. `origin_display`

These fields directly affect `taf list`, `taf which`, `taf uninstall`, and alias refresh.
