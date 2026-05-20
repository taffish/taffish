# taf-core Hub System

The Hub system lives in `taf-core/hub/` and handles TAFFISH app indexing, query, search, install, maintenance, uninstall, and lookup.

## Role

The Hub system lifts taf-apps from "local projects" into "discoverable, installable, updatable ecosystem objects". It does not compile the TAF language itself; it builds index and install logic around already published packages, artifacts, versions, and commands.

## Core Files

| File | Role |
| --- | --- |
| `update.lisp` | Update local Hub index. |
| `info.lisp` | Load index and resolve package, command, artifact, version. |
| `search.lisp` | Search index. |
| `install.lisp` | Install Hub packages. |
| `uninstall.lisp` | Uninstall packages. |
| `list.lisp` | List local installations. |
| `which.lisp` | Locate commands or install paths. |
| `upgrade.lisp` | Plan and apply outdated/install-all/upgrade/prune operations. |

## Index Contract

`hub/info.lisp` currently expects the local index schema:

```text
taffish.index/v1
```

The index is one of the most important external contracts of the Hub system. It
connects GitHub/Gitee releases, local installation state, `taf` query behavior,
container digest/platform metadata, and declared smoke metadata.

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

Long-term, the Hub system needs its own documentation. That is beyond the first source-code developer manual phase, but this page should keep interface boundaries clear.
