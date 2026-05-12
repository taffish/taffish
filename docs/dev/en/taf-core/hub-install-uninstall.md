# hub/install, uninstall

`hub/install.lisp` and `hub/uninstall.lisp` manage local installation state for TAFFISH apps.

## Role Of install

`hub-install` installs a package/version from the Hub index into TAFFISH home:

1. Resolve query and version.
2. Resolve source URL and apply source rewrite.
3. Resolve dependencies.
4. Clone or copy source.
5. If the index provides `source.commit`, verify Git `HEAD` and clean worktree.
6. Call `project-build` to build command wrapper.
7. Write launcher.
8. Write install metadata.
9. Refresh command alias.

`hub-install-from-project` installs a local/private TAFFISH project without
reading the index. It runs `project-check`, builds an in-memory install record
from the local `taffish.toml`, calls the same installer pipeline, records
origin as `[local-project] <PROJECT-DIR>`, and does not auto-install
dependencies in the first version.

## Installation Directory

Install root for a package/version:

```text
apps/<package-name>/<version-id>/
```

Main contents:

```text
source/
install.json
```

Command entries are placed in:

```text
bin/<artifact-name>
bin/<command-name>
```

The artifact launcher points to the exact version. The command alias points to the newest installed version of that command.

## Install Metadata

`install.json` schema:

```text
taffish.install/v1
```

It records:

1. scope.
2. package name.
3. version id.
4. artifact name.
5. command name.
6. command file.
7. launcher file.
8. bin dir.
9. install root.
10. source dir.
11. repository/source/ref/commit.
12. actual/verified source commit when commit verification ran.
13. origin kind/value/display.

`list`, `which`, and `uninstall` all depend on this metadata.

## Source URL And Rewrite

Source URL priority:

1. `source.local_path` in the record.
2. `source.clone_url` in the record.
3. `source.repository_url` in the record.
4. `repository_url` in the record.

Before install, system config source rewrite is applied. The china profile rewrites GitHub source to the Gitee mirror.

If the record contains `source.commit`, install verifies the resolved source
before build:

1. `git rev-parse HEAD` must equal `source.commit`.
2. `git status --porcelain --untracked-files=all` must be empty.
3. A mismatch or dirty source aborts installation and triggers cleanup.

This keeps mirror/source-rewrite installs auditable without mutating app source.

## Dependency Installation

`dependencies` in a record must be an object. Dependency versions may be:

1. string.
2. string array.
3. `latest`, `*`, or empty value, meaning latest.

Install recursively installs dependencies and uses `*hub-install-stack*` to detect dependency cycles.

## force And dry-run

`force-p` allows replacing an existing install root or launcher. `dry-run-p` returns only the planned result and does not clone, build, or write files.

On installation failure, written launchers and install root are cleaned up to avoid half-installed state.

## Role Of uninstall

`hub-uninstall` finds an installed entry by query and optional version-id, then removes:

1. install root.
2. artifact launcher.
3. command alias, if the alias actually points to this command file.

After uninstall, it refreshes the command alias to point to the newest remaining version. If no remaining version exists, it removes the alias.

## Query Matching

Uninstall can match:

1. package name.
2. artifact name.
3. command base.

If multiple versions match and no version-id is specified, the user is asked to specify the version explicitly.

## Modification Guide

When changing install/uninstall, check:

1. Whether `install.json` schema remains compatible with list/which/uninstall.
2. Whether alias refresh handles multiple versions correctly.
3. Whether source rewrite is defined only in the config layer.
4. Whether failure cleanup is complete.
5. Whether recursive dependencies avoid cycles.
6. Whether dry-run produces no side effects.
7. Whether source commit verification still runs before `project-build`.
