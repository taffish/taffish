# hub/list, which

`hub/list.lisp` lists locally installed apps or apps in the index. `hub/which.lisp` locates concrete files for a local installation.

## hub/list

`hub-list` has two modes:

| mode | Meaning |
| --- | --- |
| `:local` / `:installed` | List locally installed apps. |
| `:online` / `:index` | List apps in the local index. |

It supports scope, limit, and JSON output.

## local list

Local list scans:

```text
apps/*/*/install.json
```

It reads install metadata and outputs:

1. package name.
2. version id.
3. artifact name.
4. command name.
5. launcher file.
6. bin dir.
7. command file.
8. install root.
9. source dir.
10. metadata file.
11. repository/source/ref/commit.
12. origin kind/value/display.
13. installed_at.
14. file existence status.

Local items are sorted by package name, with newer versions first within the same package.

## online list

Online list reads packages from `index/current.json` and shows the latest record for each package:

1. name.
2. latest version id.
3. versions.
4. kind.
5. command name.
6. repository URL.
7. container image.

## JSON Schema

`hub-list` JSON output schema:

```text
taffish.list/v1
```

This is suitable for future scripts, GUIs, or Hub management tools.

## hub/which

`hub-which` locates a local installation:

1. Find matching install entry.
2. Read command file, repository, source ref, source commit, and origin.
3. Check whether launcher, command, install root, source dir, and metadata exist.
4. Check whether bin is in PATH.

JSON output schema:

```text
taffish.which/v1
```

## which Matching Rules

`which` reuses uninstall matching logic, by:

1. package name.
2. artifact name.
3. command base.

If multiple versions match, version-id is required.

## Modification Guide

When changing list/which, check:

1. Whether install metadata fields changed.
2. Whether JSON schema needs upgrading.
3. Whether multi-version sorting is consistent with install alias logic.
4. Whether PATH checks match bin rules in system/home.
