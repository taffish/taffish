# input.lisp

`input.lisp` normalizes external input arguments and runtime context into structures that `taffish-core` can consume.

## Role

A TAF program describes "what to do", but actual execution also needs information from the outside world: who the user is, where the working directory is, what arguments were passed, and which container backends are available.

`input.lisp` organizes that external information into two object types:

1. `han.args:args-input`
2. `taf-context`

## normalize-input-args

`normalize-input-args` accepts a list such as:

```lisp
("command" "--name" "alice")
```

The first item is treated as command, and later items as argv. Internally the function calls:

```lisp
han.args:parse-args-input
```

If the input is not a list, it signals an ordinary `error`.

## normalize-input-context

`normalize-input-context` accepts an alist or `nil` and outputs `taf-context`.

Known keys:

| key | taf-context field |
| --- | --- |
| `:user` | `user` |
| `:homedir` | `homedir` |
| `:workdir` | `workdir` |
| `:loaddir` | `loaddir` |
| `:argv` | `argv` |
| `:cmd` | `cmd` |
| `:cpus` | `cpus` |
| `:container` | `container` |

Unknown keys are preserved in `taf-context-extras` for future extension.

## Default Container Config

`%default-container-config` defines defaults used by the container emitter:

| key | Default or role |
| --- | --- |
| `:backend-order` | `(:apptainer :podman :docker)` |
| `:available-backends` | Currently available backends; default empty. |
| `:force-backend` | Forced backend; default `nil`. |
| `:pass-user-env-p` | Whether to pass USER/HOME and related user environment. |
| `:mount-homedir-p` | Whether to mount home. |
| `:mount-workdir-p` | Whether to mount workdir. |
| `:container-home-mode` | Container home rule; default `:same-as-host`. |
| `:extra-mounts` | Extra mounts. |
| `:docker-heredoc-quoted-p` | Whether Docker heredoc is quoted. |
| `:podman-heredoc-quoted-p` | Whether Podman heredoc is quoted. |
| `:apptainer-heredoc-quoted-p` | Whether Apptainer heredoc is quoted. |
| `:docker-run-args` | Extra Docker run args. |
| `:podman-run-args` | Extra Podman run args. |
| `:apptainer-exec-args` | Extra Apptainer exec args. |
| `:apptainer-image-dir` | SIF search and cache directories. |
| `:apptainer-quiet-p` | Whether to use quiet mode. |
| `:apptainer-auto-pull-p` | Whether to auto-pull when SIF does not exist. |
| `:apptainer-pull-source` | Default conversion from Docker source. |

The caller-provided `:container` alist overrides defaults. Unknown container keys are preserved.

## Relationship With Binder

The input layer only normalizes. The binder converts `taf-context` into built-in parameter bindings such as `*WORKDIR*`, `*CPUS*`, and `*CONTAINER*`.

## Modification Guide

When changing `input.lisp`, check:

1. Whether `binder.lisp` depends on new context fields.
2. Whether `container.lisp` depends on new container keys.
3. Whether defaults fit a minimal run without config files.
4. Whether the system config layer should expose corresponding settings.

Do not implement CLI help, project config reading, or shell generation in the input layer.

