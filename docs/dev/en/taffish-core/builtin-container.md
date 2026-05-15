# container emitter

`emitter/builtins/container.lisp` implements container tags and is one of the core implementations of TAFFISH portability. It supports Docker, Podman, and Apptainer, and can select the actual backend according to context.

## Role

The container emitter wraps a TAF block as a container run command. It solves:

1. Backend selection.
2. Image existence checks and pulls.
3. home and workdir mounts.
4. User environment forwarding.
5. Differences between Docker/Podman and Apptainer.
6. Single-command execution and heredoc execution.

## Tag Format

Basic form:

```taf
RUN
<container:ubuntu:22.04>
echo hello
```

Fuller form:

```text
<CONTAINERS:IMAGE$RUN-ARGS>
```

Parts:

| Part | Meaning |
| --- | --- |
| `CONTAINERS` | `container`, `docker`, `podman`, `apptainer`, or a `/` combination. |
| `IMAGE` | Container image. Must not be empty. |
| `$RUN-ARGS` | Optional arguments appended to backend run arguments. |

Legacy all-backend example:

```taf
<docker/podman:ubuntu:22.04$--network host>
```

Backend-specific structured arguments use `@[...]` blocks after `$`:

```taf
<container:ubuntu:22.04$@[docker: --gpus all][podman: --device nvidia.com/gpu=all][apptainer: --nv]>
```

Supported block targets are `all`, `docker`, `podman`, and `apptainer`.
Targets may be combined with `/`, for example `[docker/podman: --network host]`.
`container` is accepted as an alias for `all` inside structured run-args.

Examples:

```taf
<container:ubuntu:22.04$@[all: --network host]>
echo shared args
```

```taf
<container:ubuntu:22.04$@[docker/podman: --security-opt=label=disable][apptainer: --nv]>
echo backend-specific args
```

Structured run-args are selected after the backend is chosen. For the same
generic `<container:...>` tag, forcing `TAFFISH_CONTAINER_BACKEND=docker`,
`podman`, or `apptainer` can therefore produce different final run args from the
same source.

If the tag starts with a single quote, it forces quoted heredoc.

## Backend Selection

`container` expands to `:backend-order` from context. Default:

```lisp
(:apptainer :podman :docker)
```

Actual selection also considers:

1. `:available-backends`
2. `:force-backend`
3. Backend kinds requested in the tag

If `:force-backend` is set and the tag allows `:container`, the forced backend is preferred. Otherwise selection follows availability and order.

## Docker And Podman

Docker and Podman share most logic:

1. Check whether the command exists.
2. Check whether the image exists.
3. Pull the image if it does not exist.
4. Generate `docker run` or `podman run`.
5. Default to `--rm -i`.
6. Set workdir.
7. Append default mounts, config arguments, tag arguments, and environment
   runtime arguments.

Default mounts include:

1. home.
2. workdir.
3. extra mounts.

Default environment variables include:

1. `HOME`
2. `USER`

Runtime environment variables can append local backend-specific args without
editing the `.taf` file:

1. `TAFFISH_DOCKER_RUN_ARGS`
2. `TAFFISH_PODMAN_RUN_ARGS`
3. `TAFFISH_APPTAINER_RUN_ARGS`

The effective order is default args, context config args, tag args, then
environment runtime args.

This split is intentional:

1. Put app requirements in tag args, because they belong to the taf-app source.
2. Put local site/runtime policy in environment variables, because it belongs to
   the machine or cluster where the command runs.

## Apptainer

Apptainer logic is more complex because it needs to handle SIF files:

1. Search for SIF in `:apptainer-image-dir`.
2. If not found, find a writable directory.
3. Decide whether to pull according to `:apptainer-auto-pull-p`.
4. Generate pull source according to `:apptainer-pull-source`.
5. Check `mksquashfs` when converting Docker/OCI images.
6. Run with `apptainer exec`.

The SIF filename is derived from the image string by replacing `/`, `:`, and `@` with `_`.

## Single Command And Heredoc

The container emitter tries to decide whether a block contains only one simple command. If so, and heredoc is not forced, the command is placed directly after the container command.

Otherwise it uses:

```sh
bash <<EOF
...
EOF
```

or quoted heredoc:

```sh
bash <<'EOF'
...
EOF
```

Quoted heredoc avoids early variable expansion by the host shell.

## Debug Prelude

The container emitter generates dedicated debug comments, including:

1. chosen backend.
2. requested backends.
3. backend order.
4. available backends.
5. force backend.
6. image.
7. final run args.
8. payload limit.
9. heredoc quoted state.

This is important for diagnosing container problems on user machines.

## Modification Guide

Changing the container emitter requires considering three compatibility targets together:

1. Docker.
2. Podman.
3. Apptainer.

Also check:

1. Default container config in `input.lisp`.
2. Whether the system config layer should expose a new option.
3. Whether shell quoting is safe.
4. Whether home/workdir mounts may overwrite user data.
5. Whether China-user mirrors or network environments need additional source rewrite support.

The container emitter is an important display of TAFFISH's strength, but also the riskiest emitter. Do not add logic tightly bound to a specific bioinformatics tool here.
