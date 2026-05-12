# TAFFISH Project Specification

This page defines taf-app project layout, `taffish.toml`, build artifacts, and release conventions.

## Specification Status

| Scope | Status | Notes |
| --- | --- | --- |
| Project root and `taffish.toml` | Draft v0.1 stable | `taf` project commands depend on this convention to locate projects. |
| `[package]`, `[repository]`, `[command]`, `[runtime]` | Draft v0.1 stable | Shared foundation for `project-check`, `build`, `publish`, and `install`. |
| `[container]` | Draft v0.1 stable | Image/tag consistency is already protected by checks. |
| `[dependencies]` | Draft v0.1 semi-stable | Flow dependency synchronization exists; complex dependency resolution still needs Hub migration validation. |
| GitHub release flow | Current implementation | `taf publish` currently targets GitHub; Gitee is a mirror distribution layer. |

## Project Root

A TAFFISH project root is identified by `taffish.toml`. Project commands search upward from the current directory for `taffish.toml`; the directory containing it becomes the project root.

Typical project layout:

```text
<project>/
  taffish.toml
  src/
    main.taf
  docs/
    help.md
  target/
  README.md
  LICENSE
  release.md
```

`docs/help.md` is read by the built command wrapper for `-h` and `--help`, so the current specification requires it to exist.

## Restricted TOML Subset

The current reference implementation is not a full TOML parser. It supports only the restricted subset required by `taffish.toml`:

1. Section lines, for example `[package]`.
2. `key = value`.
3. Double-quoted strings.
4. String arrays, for example `["1.0-r1", "1.1-r1"]`.
5. `true` and `false`.
6. Non-negative integer literals.
7. Whole-line comments and blank lines.

Inline comments, arrays of tables, nested tables, floats, and the full TOML type system are not currently supported. Project files should remain simple, explicit, and parseable by TAFFISH itself.

## `[package]`

Required fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `name` | string | Non-empty; contains only ASCII letters, digits, `-`, and `_`; does not start with `-` or `.`. |
| `kind` | string | Must be `tool` or `flow`. |
| `version` | string | Non-empty; contains no space or tab. |
| `release` | integer | Positive integer. |
| `main` | string | Relative to project root; must point to a `.taf` file; must not escape the project root. |

Optional fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `license` | string | Non-empty string. |

`version` and `release` form the version id:

```text
<version>-r<release>
```

Release tags use:

```text
v<version>-r<release>
```

## `[repository]`

Required fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `url` | string | Currently must be a GitHub repository URL. |

Accepted GitHub URL forms:

1. `https://github.com/<owner>/<repo>`
2. `git@github.com:<owner>/<repo>`
3. `ssh://git@github.com/<owner>/<repo>`

Gitee mirrors belong to source rewrite and ecosystem distribution. They do not change the canonical repository URL in the project.

## `[command]`

Required fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `name` | string | Must start with `taf-`. |

The build artifact name is:

```text
<command.name>-v<package.version>-r<package.release>
```

Example:

```text
taf-demo-v0.1.0-r1
```

## `[runtime]`

Required fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `pipe` | boolean | Whether the tool is designed as a pipeline-style command. |
| `command_mode` | boolean | Whether taf-app wrapping enables command mode. |

`taf new --tool` currently defaults to:

```toml
[runtime]
pipe = true
command_mode = true
```

`taf new --flow` currently defaults to:

```toml
[runtime]
pipe = false
command_mode = false
```

## `[container]`

Optional fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `image` | string | Container image name; tag must equal `<version>-r<release>`. |
| `dockerfile` | string | Relative to project root; file must exist; must not escape the project root. |
| `build_platforms` | string | Comma-separated platform list, for example `linux/amd64,linux/arm64`. |
| `platforms` | string | Legacy field; equivalent to `build_platforms`. |

If `image` is set, the main TAF file must contain a static container tag, and the image in that tag must match `[container].image`.

The tag of `[container].image` must match:

```text
<package.version>-r<package.release>
```

Example:

```toml
[package]
version = "0.1.0"
release = 1

[container]
image = "ghcr.io/taffish/demo:0.1.0-r1"
```

## `[smoke]`

Containerized projects must declare `[smoke]`. Non-container projects may omit
it. `taf check` validates this section but does not execute smoke tests.

Fields:

| Field | Type | Constraint |
| --- | --- | --- |
| `backend` | string | Optional; one of `docker`, `podman`, `apptainer`; default is `docker`. |
| `timeout` | integer | Optional positive integer seconds; default is `60`. |
| `exist` | string array | Optional executable names that should exist in container `PATH`. |
| `test` | string array | Optional shell commands that should exit with status `0`. |

At least one of `exist` or `test` must be non-empty.
Default `TODO` placeholders generated by scaffolding are invalid and must be
replaced before the project passes `taf check`.

Example:

```toml
[smoke]
backend = "docker"
timeout = 60
exist = ["sh"]
test = ["sh -c true"]
```

Smoke metadata is intended for Hub/index automation. The final index builder
can run these checks against the published image, record digest/platform
metadata, and reject failed versions from the public index.

## `[dependencies]`

`[dependencies]` records taf commands required by a flow.

Field rules:

1. Keys must start with `taf-`.
2. Values can be strings or string arrays.
3. Empty arrays are invalid.
4. Values are usually `latest` or `<version>-r<release>`.

Example:

```toml
[dependencies]
taf-fastqc = "0.12.1-r1"
taf-samtools = ["1.20-r1", "latest"]
```

`[[taf:...]]` dependency references in flows are synchronized back to `[dependencies]` during `taf build`. If the main TAF file references a dependency that TOML does not declare, `taf check` should report an error and suggest running `taf build` to synchronize it.

## Build Artifacts

`taf build` currently can produce a command wrapper and an optional container image.

Command wrapper output:

```text
target/
  <artifact-name>
  .<artifact-name>/
    taffish.toml
    src/
    docs/
```

At runtime, the wrapper:

1. Finds the main TAF file in the snapshot.
2. Invokes `taffish` to compile it into a temporary shell script.
3. Executes the temporary shell script.
4. Writes history JSONL.
5. Supports `--version`, `--compile`, and `--help`.

## Release Conventions

`taf publish` currently targets GitHub. The default mode is dry-run; git and `gh` operations run only when dry-run is explicitly disabled.

Release tag:

```text
v<version>-r<release>
```

Before release:

1. `project-check` passes.
2. `LICENSE` exists, is non-empty, and is not a placeholder.
3. If release is enabled, `release.md` exists in the project root.
4. The first line of `release.md` is non-empty and does not contain `TODO`.
5. A normal `latest` release must be greater than the latest remote tag; pre-releases may relax this rule.

TAFFISH does not handle GitHub login. Users configure SSH keys, credential helpers, or `gh auth login` themselves.
