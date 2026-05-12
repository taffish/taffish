# TAFFISH Home And System Layout Specification

This page defines the user-level and system-level home layout for TAFFISH.

## Scope

TAFFISH supports two scopes:

| Scope | Meaning |
| --- | --- |
| `user` | Current-user installation and configuration. |
| `system` | System-wide installation and configuration. |

In command arguments or internal APIs, `nil` defaults to `user`.

## Home Paths

Default paths:

| Item | Default | Environment Override |
| --- | --- | --- |
| user home | `$HOME/.local/share/taffish/` | `TAFFISH_USER_HOME` |
| system home | `/opt/taffish/` | `TAFFISH_SYSTEM_HOME` |
| system command bin | `/usr/local/bin/` | `TAFFISH_SYSTEM_BIN_DIR` |

Paths should be normalized as directory paths and preserve trailing-slash directory semantics.

## Config File Location

The config file name under each home is fixed:

```text
config.toml
```

Therefore:

```text
<user-home>/config.toml
<system-home>/config.toml
```

`TAFFISH_CONFIG` can point to an additional explicit config file. See [TAFFISH Configuration Specification](system-config-spec.md) for merge order.

## Required Directories

`taf doctor --init` should ensure the following directories exist under the active home:

```text
apps/
index/
index/snapshots/
images/
images/sif/
images/metadata/
images/locks/
images/tmp/
bin/
cache/
cache/repos/
cache/downloads/
cache/build/
share/
share/completions/
share/completions/bash/
share/completions/zsh/
share/completions/fish/
share/vim/
share/vim/syntax/
share/vim/ftdetect/
logs/
```

These directories are the long-term layout for TAFFISH local state and must not be renamed casually.

## Hub Index Files

Current index file:

```text
<home>/index/current.json
```

Snapshot files:

```text
<home>/index/snapshots/index-<timestamp>.json
```

The timestamp comes from UTC time. Safe filenames remove `:` and `-`.

## App Installation Layout

Apps are installed at:

```text
<home>/apps/<package-name>/<version-id>/
```

Inside that directory:

```text
source/
install.json
```

`source/` stores the cloned or copied taf-app source. `install.json` stores install metadata; see [TAFFISH Install Metadata Specification](install-metadata-spec.md).

## Command Bin

User-scope command bin:

```text
<user-home>/bin/
```

System-scope command bin:

```text
<system-bin-dir>/
```

Installation writes:

1. A versioned artifact launcher, for example `taf-demo-v0.1.0-r1`.
2. A command alias launcher, for example `taf-demo`.

If multiple versions exist for the same command alias, the alias should point to the latest version id.

## Permission Requirements

Initializing `system` scope requires root permissions. `taf doctor` should check whether directories exist, whether they are writable, and whether the command bin is in `PATH`.

If directories are missing and `--init` was not passed, doctor status should be `needs-init`. If a directory is not writable, status should be `permission-warning`.

