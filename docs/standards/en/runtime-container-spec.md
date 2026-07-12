# TAFFISH Runtime And Container Specification

This page defines TAFFISH runtime context, generated shell behavior, and the main container backend contracts.

## Specification Status

| Scope | Status | Notes |
| --- | --- | --- |
| Known context fields | Draft v0.2 stable | Compilation and built-in parameters depend on these fields. |
| Docker/Podman/Apptainer backend selection | Draft v0.2 stable | Core rule for current container portability. |
| Default mounts and HOME/USER forwarding | Draft v0.2 semi-stable | Usable now, but advanced HPC contexts may need extensions. |
| SIF cache and auto pull | Draft v0.2 semi-stable | Implemented; future work may add locks, metadata, and cleanup policy. |
| Backend-specific runtime arguments | Draft v0.2 semi-stable | Structured tag arguments and local runtime environment variables are implemented; new targets or policy layers may still be added. |

## Runtime Context

`taffish-core` receives a context alist during compilation and normalizes it into `taf-context`.

Known fields:

| Field | Meaning |
| --- | --- |
| `:user` | Host username. |
| `:homedir` | Host home directory. |
| `:workdir` | Host working directory. |
| `:loaddir` | Directory where the TAF file is loaded. |
| `:argv` | Raw argv. |
| `:cmd` | Command name. |
| `:cpus` | Available CPU count. |
| `:container` | Container configuration alist. |

Unknown fields should be stored in `taf-context-extras` for future extension.

## Default Container Configuration

Default container configuration:

```lisp
((:backend-order . (:apptainer :podman :docker))
 (:available-backends . ())
 (:force-backend . nil)
 (:pass-user-env-p . t)
 (:mount-homedir-p . t)
 (:mount-workdir-p . t)
 (:container-home-mode . :same-as-host)
 (:extra-mounts . nil)
 (:docker-heredoc-quoted-p . nil)
 (:podman-heredoc-quoted-p . nil)
 (:apptainer-heredoc-quoted-p . nil)
 (:docker-run-args . nil)
 (:podman-run-args . nil)
 (:apptainer-exec-args . nil)
 (:apptainer-image-dir . ("${TAFFISH_SYSTEM_HOME:-/opt/taffish}/images/sif"
                          "${TAFFISH_USER_HOME:-$HOME/.local/share/taffish}/images/sif"))
 (:apptainer-quiet-p . t)
 (:apptainer-auto-pull-p . t)
 (:apptainer-pull-source . :docker))
```

Callers may override these keys. Unknown container keys are currently preserved in the config alist, but built-in emitters should not depend on unknown keys.

## Container Tag Syntax

Container subtags have forms such as:

```taf
<CONTAINERS:IMAGE>
<CONTAINERS:IMAGE$RUN-ARGS>
<CONTAINERS:IMAGE$@[TARGET: RUN-ARGS][TARGET: RUN-ARGS]>
<'CONTAINERS:IMAGE>
```

`CONTAINERS` can be:

1. `container`
2. `docker`
3. `podman`
4. `apptainer`
5. A `/`-joined candidate list, for example `docker/podman`

`container` is a virtual backend expanded according to `:backend-order`.

`IMAGE` must not be empty. Legacy `$RUN-ARGS` is an all-backend raw argument
string appended to the selected backend command.

Structured `$@[TARGET: RUN-ARGS]` blocks let an app state backend-specific
requirements. Supported targets are:

1. `all` or `container`: every selected backend.
2. `docker`, `podman`, or `apptainer`: one backend.
3. A `/`-joined set such as `docker/podman`: every named backend in the set.

All matching blocks contribute arguments in source order. For example:

```taf
<container:ghcr.io/taffish/my-gpu-tool:1.0.0-r1$@[docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
my-gpu-tool --help
```

An app-level cross-backend requirement can use `all`, while a related
Docker/Podman-only requirement can use a combination target:

```taf
<container:ghcr.io/taffish/my-tool:1.0.0-r1$@[all: --network host][docker/podman: --security-opt=label=disable]>
my-tool --help
```

If tag content starts with a single quote, for example:

```taf
<'docker:ghcr.io/taffish/demo:0.1.0-r1>
```

it forces heredoc form and uses quoted heredoc delimiter mode.

## Backend Selection

Backend selection:

1. If the tag explicitly specifies `docker`, `podman`, or `apptainer`, select only from those candidates.
2. If the tag uses `container`, expand according to `:backend-order`.
3. `:force-backend` takes effect only when the candidates include `:container`.
4. The final backend must exist in `:available-backends`.
5. If no backend is available, report an error.

`taf compile` and the project compilation layer detect local executables to populate `:available-backends`; detection order includes Apptainer, Podman, and Docker.

Runtime callers may force the backend for generic `<container:...>` tags by setting `:container :force-backend`. In the CLI/project layer, the source priority is:

1. explicit command option, for example `taf run --backend podman`.
2. `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker`.
3. no forced backend.

This force rule does not override explicit backend tags such as `<docker:...>`, `<podman:...>`, or `<apptainer:...>`.

## Runtime Argument Layers

Container runtime arguments are merged in this order:

1. TAFFISH backend defaults.
2. Project or caller context configuration, such as `:docker-run-args`.
3. Legacy or structured arguments declared in the `.taf` container tag.
4. Local backend environment variables.

The local variables are:

| Backend | Environment variable |
| --- | --- |
| Docker | `TAFFISH_DOCKER_RUN_ARGS` |
| Podman | `TAFFISH_PODMAN_RUN_ARGS` |
| Apptainer | `TAFFISH_APPTAINER_RUN_ARGS` |

Tag arguments describe app requirements that should travel with the executable
package, such as backend-specific GPU exposure. Environment variables describe
machine, site, scheduler-wrapper, scratch-mount, proxy, or one-run policy that
should not change published app source. Local environment arguments are
appended last; they extend rather than erase earlier layers.

TAFFISH remains an execution layer, not a scheduler. CPU, memory, queue, and
wall-time requests belong in the surrounding HPC job script or workflow
system unless they are ordinary arguments of the wrapped tool itself.

## Docker/Podman Runtime Contract

Docker and Podman use shared logic:

1. Check whether the backend command exists.
2. Check whether the image exists locally.
3. Pull the image if it does not exist.
4. Use `run --rm -i`.
5. Set workdir.
6. Mount home, workdir, and extra mounts.
7. Pass HOME and USER according to config.
8. A simple one-line command can be passed directly as the command.
9. Multi-line or complex commands use heredoc.

Default mounts:

| Config | Behavior |
| --- | --- |
| `:mount-homedir-p` | Mount host homedir to container home. |
| `:mount-workdir-p` | Mount host workdir to the same path. |
| `:extra-mounts` | Add `-v` mounts item by item. |

Backend-specific extra arguments:

| Backend | Config key |
| --- | --- |
| Docker | `:docker-run-args` |
| Podman | `:podman-run-args` |

## Apptainer Runtime Contract

Apptainer execution flow:

1. Check whether `apptainer` exists.
2. Derive a SIF filename from the image.
3. Search for an existing SIF in `:apptainer-image-dir`.
4. If not found, choose a writable directory as the SIF target.
5. If auto pull is allowed, run `apptainer pull`.
6. If pulling from Docker/OCI sources, require `mksquashfs`.
7. Run with `apptainer exec --pwd <workdir>`.

For system installs, a command wrapper can be globally visible even when no
system SIF has been pre-cached yet. If neither the system SIF directory nor the
current user's SIF directory is writable, generated shell reports:

```text
[TAFFISH] no writable apptainer image directory found
```

This is expected behavior. Administrators can pre-cache SIF files, users can
initialize their own TAFFISH user home, or the site can intentionally configure
a sticky shared SIF directory such as `/opt/taffish/images/sif` with mode
`1777`.

SIF filenames are derived from image strings by converting:

```text
[/:@] -> _
```

and appending `.sif`.

Apptainer pull source:

| Config value | Pull ref |
| --- | --- |
| `:docker` | `docker://<image>` |
| `:oras` | `oras://<image>` |
| `:library` | `library://<image>` |

The default is `:docker`.

## Container Home

`container-home-mode` currently supports:

| Value | Behavior |
| --- | --- |
| `:same-as-host` or `nil` | Container home equals host homedir. |
| `:linux-user-home` | `/home/<user>`, or `/home/user` when user is missing. |

Workdir selection:

1. If `:mount-workdir-p` is true and host workdir is available, use host workdir.
2. Otherwise, if container home exists, use container home.
3. Otherwise, use `/work`.

## Heredoc And Single Commands

The container emitter checks whether a block is a single simple command. A simple command must not contain these shell control characters:

```text
; & | < > `
```

and must not contain `$(`.

Simple commands can be passed directly as backend commands. Otherwise TAFFISH uses:

```sh
bash <<EOF
...
EOF
```

Quoted heredoc uses:

```sh
bash <<'EOF'
...
EOF
```

## Debuggability Of Generated Shell

Container emitters should output a debug prelude that includes:

1. Chosen backend.
2. Requested backends.
3. Backend order.
4. Available backends.
5. Force backend.
6. Image.
7. Final run args.
8. Payload mode.
9. Heredoc quoted state.

These comments are part of generated shell readability and should not be removed casually.
