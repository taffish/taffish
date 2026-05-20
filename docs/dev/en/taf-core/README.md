# taf-core

`taf-core` is the business core behind the `taf` command. It extends the compilation capability of `taffish-core` into project, build, run, Hub, install, config, and diagnostic workflows.

## Role

`taffish-core` answers "how to compile TAF into shell", while `taf-core` answers "how to use TAF as a distributable, installable, runnable, maintainable application ecosystem".

## System Position

```text
taffish-core
  -> taf-core
  -> taf-cli
```

`taf-core` may call `taffish-core`, but `taffish-core` should not depend back on `taf-core`.

## Subsystems

| Subsystem | Path | Role |
| --- | --- | --- |
| project | `project/` | taf-app project creation, checking, compilation, build, run, and publish. |
| hub | `hub/` | Index update, query, search, install, maintenance, uninstall, and lookup. |
| system | `system/` | Home directories, config, history, and diagnostics. |

## Public API

APIs exported by `taf-core/package.lisp` cover three capability groups:

| Category | Examples |
| --- | --- |
| Project | `project-new`, `project-check`, `project-compile`, `project-build`, `project-run`, `project-publish` |
| Hub | `hub-update`, `hub-info`, `hub-search`, `hub-install`, `hub-install-all`, `hub-outdated`, `hub-upgrade`, `hub-prune`, `hub-uninstall`, `hub-list`, `hub-which` |
| System | `system-config`, `system-config-path`, `system-config-init`, `system-doctor`, `system-history`, `system-record-history-event` |

The exact export list should be checked in `taf-core/package.lisp`.

## Design Boundaries

`taf-core` is the business layer, but its boundaries should remain clear:

1. Project metadata checking belongs in `project/check.lisp`.
2. Hub index schema and package parsing belong in Hub files such as `hub/info.lisp`.
3. Config defaults and source merging belong in `system/config.lisp`.
4. Filesystem directory conventions belong in `system/home.lisp`.
5. CLI wording and subcommand dispatch should live mostly in `taf-cli`, not inside `taf-core`.

## Related Topics

- [Project System](project-system.md)
- [project/common And package](project-common.md)
- [project/new](project-new.md)
- [project/check](project-check.md)
- [project/compile And project/run](project-compile-run.md)
- [project/build](project-build.md)
- [project/publish](project-publish.md)
- [Hub System](hub-system.md)
- [hub/update, info, search](hub-index-query.md)
- [hub/install, uninstall](hub-install-uninstall.md)
- [hub/outdated, install-all, upgrade, prune](hub-maintenance.md)
- [hub/list, which](hub-list-which.md)
- [System Layer](system-layer.md)
- [system/home And config](system-home-config.md)
- [system/history And doctor](system-history-doctor.md)
