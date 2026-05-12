# project/build

`project/build.lisp` generates distributable command wrappers and can optionally build container images.

## Role

Build is the step that turns a project directory into installable artifacts. It outputs:

1. Command file under target.
2. Source snapshot under target.
3. Optional container image.
4. Dependency synchronization for flow projects.

## Artifact Naming

Artifact name:

```text
<command-name>-v<version>-r<release>
```

Example:

```text
taf-example-v0.1.0-r1
```

This is also the key check during Hub install to verify that the built artifact matches the index.

## Source Snapshot

`%snapshot-project-source` copies required project content to:

```text
target/.<artifact-name>/
```

Including:

1. `taffish.toml`
2. `src/`
3. `docs/`
4. Main TAF file

The generated wrapper references this snapshot rather than the development directory directly.

## Wrapper Behavior

The build wrapper is a shell script that supports:

| Argument | Behavior |
| --- | --- |
| `--` | Pass following arguments to TAF. |
| `-v` / `--version` | Output package, version, kind, repository. |
| `--compile` | Call `taffish` and output generated shell. |
| `-h` / `--help` | Output `docs/help.md` from the snapshot. |
| default | Compile TAF to a temporary shell script and execute it. |

The wrapper records runtime history to JSONL, asynchronously by default. Environment variables:

| Variable | Role |
| --- | --- |
| `TAFFISH` | Specify taffish compiler path. |
| `TAF_HISTORY_MODE` | `async`, `sync`, or `off`. |
| `TAF_HISTORY_FILE` | Specify history file. |
| `TAFFISH_USER_HOME` | Default history home. |

## Flow Dependency Synchronization

For flow projects, `%build-sync-flow-dependencies` scans `[[taf: ...]]` references in the main TAF and rewrites the `[dependencies]` section of `taffish.toml`.

This keeps the actual composition dependencies of a flow consistent with project metadata.

## Container Image Build

If `project-build` receives `:image-p t`, it uses Docker or Podman to build the image.

Backend selection:

1. Explicit `backend`.
2. Available Docker in the system.
3. Available Podman in the system.

The build command is roughly:

```sh
docker build -t <image> -f <dockerfile> <root>
```

## Modification Guide

When changing build, check:

1. Whether wrapper output remains compatible with install, which, and history.
2. Whether artifact naming remains consistent with the Hub index.
3. Whether the snapshot contains all files required at runtime.
4. Whether flow dependency sync remains consistent with `project-check` rules.
5. Whether the container image tag still matches `[package].version/release`.

