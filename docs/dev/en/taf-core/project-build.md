# project/build

`project/build.lisp` generates distributable command wrappers and can optionally build container images.

## Role

Build is the step that turns a project directory into installable artifacts. It outputs:

1. Command file under target.
2. Source snapshot under target.
3. Private build manifest inside the snapshot.
4. Optional container image.
5. Dependency synchronization for flow projects.

Flow synchronization uses the same source-only inline boundaries as `taf check`
and the compiler. Quoted closing markers and parameter defaults cannot create
extra dependencies. Version normalization and `[dependencies]` rewriting retain
their existing rules; see [Project Check](project-check.md).

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
5. `.taf-build.json`, containing the artifact, source, and wrapper identities

The generated wrapper references this snapshot rather than the development directory directly.

## Exact And Idempotent Command Build

Command-wrapper build computes a stable SHA-256 identity over `taffish.toml`,
`src/`, and `docs/`, including directory layout and binary file content. It
also computes the exact wrapper digest. A second build is reported as
`up-to-date` and does not rewrite the wrapper or snapshot only when the wrapper,
snapshot, executable bit, and `.taf-build.json` all match.

Missing or corrupt manifests, changed source, missing artifacts, or extra
snapshot files/directories cause one exact rebuild. This includes abnormal
residue such as `help2.md`, `docs2/`, or `src2/`; these names have no special
meaning and disappear because the rebuilt snapshot exactly matches project
source.

Rebuild uses same-directory staging and backup paths. Staged artifacts are
fully validated before replacement. If replacement fails, the last valid
wrapper and snapshot are restored. Cleanup is scoped to temporary paths for the
same artifact and does not touch another app or version.

The final wrapper pathname is exact even when the version text contains no
period, such as `492`. Staging or backup suffixes are never inherited by the
installed wrapper pathname, and residue from interrupted older transactions is
cleaned or restored within the same artifact boundary.

This idempotency applies to the command wrapper and frozen snapshot. Explicit
container image builds still invoke Docker or Podman normally.

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

## Return Data

The public result retains `:project`, `:command`, and `:image`. The command
plist retains its previous path/name/dependency fields and additionally reports
`:status` (`:rebuilt` or `:up-to-date`), `:source-sha256`,
`:wrapper-sha256`, and `:manifest-file`.

## Modification Guide

When changing build, check:

1. Whether wrapper output remains compatible with install, which, and history.
2. Whether artifact naming remains consistent with the Hub index.
3. Whether the snapshot contains all files required at runtime.
4. Whether flow dependency sync remains consistent with `project-check` rules.
5. Whether the container image tag still matches `[package].version/release`.
6. Whether repeated command builds remain write-free and failed replacement
   preserves the last valid artifact.

## Operation Status

Slow human-facing operations report their current target and stage on stderr.
TTY updates, log throttling, target-count semantics, quiet/JSON behavior and
limits are described in [command status](command-progress.md). These notices do not change
validation, mutation, retry or exit-code rules.
