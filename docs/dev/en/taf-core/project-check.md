# project/check

`project/check.lisp` is the center of the TAFFISH project contract. It reads `taffish.toml`, checks project files and the main TAF, and returns the standard project plist.

## Role

`project-check` upgrades "a directory that looks like a taf-app" into "a structurally verified taf-app project".

Many upper commands depend on it:

1. `project-compile`
2. `project-build`
3. `project-run`
4. `project-publish`
5. Source builds inside `hub-install`

## TOML Subset

The current implementation contains a small TOML parser supporting the subset TAFFISH needs:

1. Section.
2. key/value.
3. Quoted string.
4. String array.
5. Boolean.
6. Non-negative integer literal.

It is not a full TOML implementation. Do not treat it as a general TOML parser during maintenance.

## Required Sections And Fields

`project-check` reads:

| section | field | requirement |
| --- | --- | --- |
| `[package]` | `name` | Non-empty and follows project naming rules. |
| `[package]` | `kind` | `tool` or `flow`. |
| `[package]` | `version` | Non-empty and contains no whitespace. |
| `[package]` | `release` | Positive integer. |
| `[package]` | `main` | Project-relative path; must be `.taf`. |
| `[repository]` | `url` | GitHub repository URL. |
| `[command]` | `name` | Must start with `taf-`. |
| `[runtime]` | `pipe` | Boolean. |
| `[runtime]` | `command_mode` | Boolean. |

Optional fields include license, container image, dockerfile, build platforms,
smoke metadata, dependencies, and ecosystem metadata such as `[meta]` and
`[upstream]`.

## Optional Ecosystem Metadata

`project-check` currently keeps `[meta]` and `[upstream]` optional. It does not
require them, and it does not turn their absence into a local project error.
They still need to use the restricted TOML subset when present.

`project-check` does not currently interpret or normalize `[meta]` and
`[upstream]` fields into the returned project plist. Hub/index producers are
responsible for consuming ecosystem metadata such as `[upstream].repository`,
the compatibility alias `[upstream].repo`, `[upstream].license`, and scholarly
attribution fields like `[upstream].citation`, `[upstream].doi`, and
`[upstream].pmid`.

This boundary is intentional:

1. Local private apps and experiments should stay lightweight.
2. Public Hub/index producers may apply stricter curation rules.
3. Official ecosystem metadata requirements should evolve without breaking old
   local projects.

## Main TAF Check

`%check-taf-main-file` confirms that the main file exists and calls:

```lisp
taffish.core:parse-taf
```

This means `taf check` performs static TAF syntax checks, but does not bind real parameters or execute anything.

## Flow Dependency Check

For flow projects, `project-check` scans `<taffish>` blocks for:

```text
[[taf: ...]]
```

and requires `[dependencies]` in `taffish.toml` to declare those dependencies.

If an inline dependency is an exact artifact name, such as a form containing `-v...-r...`, dependencies must contain the corresponding version. Otherwise an existing declaration or `latest` semantics can be used.

When a dependency is missing, the error suggests running `taf build` to synchronize.

## Container Image Check

If `[container].image` exists, `project-check` verifies:

1. The image tag equals `<version>-r<release>`.
2. The main TAF contains a static container tag using that image.
3. The static container image in main TAF matches `taffish.toml`.

This keeps project metadata, container image, and TAF entry from drifting apart.

## Smoke Metadata Check

If a project declares `[container].image` or `[container].dockerfile`,
`project-check` requires `[smoke]` and validates:

1. `backend` is `docker`, `podman`, or `apptainer` when present.
2. `timeout` is a positive integer when present.
3. `exist` and `test` are string arrays when present.
4. At least one of `exist` or `test` is non-empty.

This check is intentionally declarative. It does not run containers. Smoke
execution belongs to Hub/index automation, which can test the final published
image and record digest/platform metadata.

## Output Project Plist

`project-check` returns a plist. Important fields include:

| Field | Meaning |
| --- | --- |
| `:root-dir` | Project root directory. |
| `:toml-file` | Path to `taffish.toml`. |
| `:name` | Package name. |
| `:kind` | `:tool` or `:flow`. |
| `:version` | Package version. |
| `:release` | Release integer. |
| `:repository-url` | GitHub repository. |
| `:command-name` | Logical command name. |
| `:main-path` | Main relative path. |
| `:main-file` | Main absolute path. |
| `:help-file` | `docs/help.md`. |
| `:target-dir` | target directory. |
| `:runtime-pipe` | Runtime pipe. |
| `:runtime-command-mode` | Runtime command mode. |
| `:container-image` | Image. |
| `:dependencies` | Normalized dependencies. |
| `:smoke` | Normalized smoke metadata plist or nil. |
| `:dockerfile` | Dockerfile relative path. |
| `:container-build-platforms` | Build platforms. |

## Modification Guide

Be very careful when changing `project-check`, because it defines the project standard:

1. When adding `taffish.toml` fields, decide whether they are required and whether old projects remain compatible.
2. When changing dependency rules, update automatic synchronization in `project-build`.
3. When changing container image rules, update `taf new` and Hub index behavior.
4. Error messages should give users an actionable repair direction.
