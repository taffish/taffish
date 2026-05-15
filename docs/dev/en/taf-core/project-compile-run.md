# project/compile And project/run

`project/compile.lisp` compiles a project's main TAF into shell. `project/run.lisp` writes that shell to a temporary directory and executes it.

## Role Of project-compile

`project-compile` is responsible for:

1. Locating the project root.
2. Calling `project-check` to obtain project metadata.
3. Reading the main TAF.
4. Constructing `taffish-core` context.
5. Calling `taffish.core:taffish-to-shell`.

It does not execute shell; it only returns the shell string.

## Context Construction

`%make-project-core-context` collects:

| key | Source |
| --- | --- |
| `:user` | Current system user. |
| `:homedir` | Home directory, falling back to `/root` or `/home/<user>` when needed. |
| `:workdir` | Absolute directory of start-dir at call time. |
| `:loaddir` | Directory containing the main TAF. |
| `:argv` | User-provided args. |
| `:cmd` | command name from `taffish.toml`. |
| `:cpus` | Detected through `getconf`, `nproc`, or `sysctl`; fallback 1. |
| `:container` | Available backends and optional forced backend. |

Available container backends are detected by looking for `apptainer`, `podman`, and `docker`.

For project compilation and run paths, the effective forced backend priority is:

1. explicit `:container-backend`, such as `taf run --backend podman`.
2. `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`.
3. no forced backend, so `<container:...>` follows normal backend selection.

The forced backend only affects generic `<container:...>` tags. Explicit `<docker:...>`, `<podman:...>`, and `<apptainer:...>` tags remain explicit.

Project compile/run also forwards local backend runtime args from:

1. `TAFFISH_DOCKER_RUN_ARGS`
2. `TAFFISH_PODMAN_RUN_ARGS`
3. `TAFFISH_APPTAINER_RUN_ARGS`

These are appended after `.taf` tag run-args in the generated shell. They are
intended for local machine policy, such as GPU flags or site-specific runtime
options, not app-level scientific semantics.

## Compile Options

Currently supported:

```lisp
:container-backend
```

It may be `apptainer`, `podman`, `docker`, or the corresponding keyword. It enters context as `:container :force-backend`.

## Role Of project-run

At runtime, `project-run`:

1. Calls `project-compile`.
2. Creates a temporary directory.
3. Writes `run.sh`.
4. chmods it executable.
5. Executes the shell.
6. Cleans the temporary directory.

Return:

```lisp
(:exit-code ... :stdout ... :stderr ...)
```

## Input And Output

`project-run` supports:

| Argument | Role |
| --- | --- |
| `:input` | stdin passed to the running program. |
| `:output` | stdout destination, default `t`. |
| `:error-output` | stderr destination, default `t`. |

## Modification Guide

When changing compile/run, check:

1. Whether context fields match `taffish-core/input.lisp` and `binder.lisp`.
2. Whether forced container backend logic affects the container emitter.
3. Whether temporary directories are always cleaned up.
4. Whether stdout/stderr return contracts affect the CLI.
5. Do not execute shell in compile, and do not reparse project metadata in run.
