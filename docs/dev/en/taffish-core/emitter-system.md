# Emitter System

Emitters are the extension mechanism in `taffish-core` that converts TAF blocks into shell fragments. They let the TAF language support different tags without hardcoding all tag logic in the compiler.

## Role

Runtime blocks in a TAF program carry tags such as shell, container, taffish, and taf-app. Different tags correspond to different shell generation strategies.

The emitter system solves:

1. How to select an implementation by tag.
2. How to unify input and output for tag implementations.
3. How to add tags without breaking the compiler main flow.

## System Position

```text
compiler
  -> emit-block
  -> registered emitter
  -> shell lines
```

The compiler only hands blocks to emitters. How a block becomes shell is decided by the matched emitter.

## Core Files

| File | Role |
| --- | --- |
| `emitter/model.lisp` | Define emitter, default prelude, and default finalize. |
| `emitter/registry.lisp` | Register emitters, match emitters by block, and execute emission. |
| `emitter/builtins/shell.lisp` | Output shell lines directly. |
| `emitter/builtins/container.lisp` | Generate Docker, Podman, Apptainer, and related container shell. |
| `emitter/builtins/taffish.lisp` | Support TAF inline composition and sub-script compilation. |
| `emitter/builtins/taf-app.lisp` | Support taf-app command mode and application-entry delegation. |

## Emitter Contract

An emitter must answer at least three questions:

1. Which tags does it match?
2. How does it convert a block into shell?
3. Does it need extra prelude or finalize behavior?

Output must remain composable as shell fragments. Emitters usually return strings or string lists, and the registry performs basic checks.

## Built-In Tag Positioning

| Tag capability | Positioning |
| --- | --- |
| shell | The most basic pass-through execution model. |
| container | One of the key implementations of TAFFISH portability. |
| taffish | Supports TAF composing TAF for higher-level workflows. |
| taf-app | Connects low-level TAF compile results to application command mode. |

## Modification Guide

When adding an emitter:

1. Do not modify the compiler main flow just to support one tag.
2. Keep tag matching clear and avoid ambiguity with existing tags.
3. Account for quoting, working directory, temporary files, and container backend differences when outputting shell.
4. If the new tag affects the TAF standard, update standard docs.

Be especially careful when modifying the container emitter, because it affects portability, safety boundaries, runtime paths, and user data mounts at the same time.

