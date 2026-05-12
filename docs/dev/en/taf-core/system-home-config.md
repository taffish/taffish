# system/home And config

`system/home.lisp` defines the TAFFISH local directory layout. `system/config.lisp` defines config files, defaults, profiles, index URL, and source rewrite.

## Role Of system/home

The home layer answers:

1. Where user-level TAFFISH home is.
2. Where system-level TAFFISH home is.
3. Where system-level bin is.
4. Which home a scope should use.
5. Which directories must exist.
6. Whether command bin is in PATH.

## Default Directories

| Type | Default |
| --- | --- |
| system home | `/opt/taffish/` |
| system bin | `/usr/local/bin/` |
| user home | `$HOME/.local/share/taffish/` |

Environment overrides:

1. `TAFFISH_USER_HOME`
2. `TAFFISH_SYSTEM_HOME`
3. `TAFFISH_SYSTEM_BIN_DIR`

## Required Directories

Required directories under a TAFFISH home include:

```text
apps
index
index/snapshots
images
images/sif
images/metadata
images/locks
images/tmp
bin
cache
cache/repos
cache/downloads
cache/build
share
share/completions/bash
share/completions/zsh
share/completions/fish
share/vim/syntax
share/vim/ftdetect
logs
```

`doctor --init` creates these directories.

## Scope

Scope can only be:

1. `:user`
2. `:system`

The user-scope command bin is `bin` under home. The system-scope command bin is system bin.

## Config Schema

Config schema:

```text
taffish.config/v1
```

Default config:

| key | Default |
| --- | --- |
| `profile` | `github` |
| `language` | `en` |
| `index-url` | GitHub raw index URL |
| `source-rewrite-rules` | nil |

## Config File Load Order

Effective config starts from defaults and then merges:

1. system config.
2. user config, only in user scope.
3. explicit config specified by `TAFFISH_CONFIG`.

Later config overrides earlier config. `config-files` records the actual loaded file list.

## Index URL Resolution Priority

`%resolve-taffish-index-url` uses:

1. Explicit URL.
2. `TAFFISH_INDEX_URL`.
3. `*taffish-index-default-url*`.
4. Index URL from effective config.
5. Default index URL.

## Source Rewrite

Source rewrite maps canonical source URLs to mirrors.

Config format:

```toml
[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

This is a key mechanism for serving users in China. Note that the GitHub organization is `taffish`, while the Gitee organization is `taffish-org`.

## Profile

`system-config-init` supports:

| profile | Behavior |
| --- | --- |
| `github` | Use GitHub raw index and no source rewrite. |
| `china` | Use Gitee index and rewrite GitHub source to Gitee. |

System-scope init requires root.

## Modification Guide

When changing home/config, check:

1. Whether doctor is synchronized with directory changes.
2. Whether hub update/install can still resolve index/source.
3. Whether Gitee/GitHub mirror rules are correct.
4. Whether new config fields require schema upgrade.
5. Whether environment variable priority matches user expectations.

