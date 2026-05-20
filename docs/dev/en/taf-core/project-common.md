# project/common And package

`taf-core/package.lisp` defines the public API of `taf.core`. `project/common.lisp` provides defaults, naming rules, path helpers, and project-root discovery shared by project, Hub, and system code.

## Role

These two files are the common foundation of `taf-core`:

1. `package.lisp` decides which capabilities are stably visible to the CLI or other modules.
2. `project/common.lisp` decides default GitHub/GHCR/index naming rules.
3. `project/common.lisp` provides project paths and project-root identification.

## Public API Groups

`taf.core` currently exports:

| Category | API |
| --- | --- |
| Defaults | `*default-github-host*`, `*default-github-owner*`, `*default-container-registry*`, `*default-docker-base-image*`, `*default-index-repository*`, `*default-index-branch*` |
| Project | `project-new`, `project-check`, `project-compile`, `project-build`, `project-run`, `project-publish` |
| Hub | `hub-update`, `hub-search`, `hub-info`, `hub-info-many`, `hub-install`, `hub-install-from-project`, `hub-install-many`, `hub-install-all`, `hub-outdated`, `hub-upgrade`, `hub-prune`, `hub-uninstall`, `hub-uninstall-many`, `hub-list`, `hub-which`, `hub-which-many` |
| System | `system-config`, `system-config-path`, `system-config-init`, `system-doctor`, `system-history`, `system-record-history-event` |

## Default Naming Rules

`project/common.lisp` currently defaults to:

| Variable | Default |
| --- | --- |
| `*default-github-host*` | `github.com` |
| `*default-github-owner*` | `taffish` |
| `*default-container-registry*` | `ghcr.io` |
| `*default-docker-base-image*` | `debian:12-slim` |
| `*default-index-repository*` | `taffish-index` |
| `*default-index-branch*` | `main` |

Note: the GitHub owner is `taffish`. The Gitee mirror owner is `taffish-org`; it is handled in the china profile of system config. These two concepts should not be mixed in project defaults.

## Project Name Rules

A project name must:

1. Be a non-empty string.
2. Contain only ASCII letters, digits, `-`, and `_`.
3. Not start with `-` or `.`.

This rule affects package name, repo URL, container image, and command name. It is a foundational constraint of the TAFFISH app ecosystem.

## Default Derived Values

`project/common.lisp` derives values from project name, version, and release:

| Function | Result |
| --- | --- |
| `%default-repository-url` | `https://github.com/taffish/<name>` |
| `%default-container-image` | `ghcr.io/taffish/<name>:<version>-r<release>` |
| `%default-index-url` | GitHub raw index URL. |

Image names replace `_` with `-` and are lowercased.

## Project Root Discovery

`%find-project-root` searches upward from the current directory for `taffish.toml`. This is the basis for default project location in `project-check`, `project-build`, `project-run`, and related commands.

## Modification Guide

When changing the common layer, check:

1. Whether `taf new` output still follows defaults.
2. Whether `taf check` still recognizes old projects.
3. Whether repository, command, and artifact names in the Hub index are affected.
4. Whether GitHub and Gitee mirror configuration still keeps boundaries clear.
