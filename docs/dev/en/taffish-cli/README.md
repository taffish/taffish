# taffish-cli

`taffish-cli` is the implementation layer for the `taffish` command. It exposes the compilation capability of `taffish-core` to command-line users.

## Role

`taffish-cli` handles command-line arguments, reads input, calls `taffish-core`, and outputs results to users or callers.

It should not contain TAF language semantics. Language semantics belong to `taffish-core`.

`main.lisp` establishes the human language through `taffish.i18n` before
dispatch. `i18n.lisp` owns the built-in English/Chinese help and top-level
missing-command diagnostic. Compiler diagnostics and generated shell remain
outside the localization layer.

## Help and input

`taffish --help` describes usage, input, container settings, examples, language,
and contact links in that order. Both built-in languages expose the same
options. `--version` remains a single command-name/version line.

Except for help/version and a leading `--`, an existing regular file in the
first argument selects file input. Otherwise the compiler reads standard input
and treats the arguments as TAF program arguments. This includes nonexistent
filenames, so a typo can leave the compiler waiting for terminal input.
`taffish -- < example.taf > example.sh` explicitly selects standard input.

`TAFFISH_CONTAINER_BACKEND` accepts `apptainer`, `podman`, or `docker`. Unset,
it selects an available backend for generic `<container:...>` tags; explicit
backend tags are unchanged. For example:

```sh
TAFFISH_CONTAINER_BACKEND=podman taffish example.taf > example.sh
```

The named backend must be available when a generic container tag is compiled.
This command only generates shell; it does not pull an image or run a container.
The three `TAFFISH_*_RUN_ARGS` settings append arguments for their corresponding
backends. Language selection never changes those variable names or generated shell.

## Error Handling

The executable entry point covers TAFFISH runtime I/O and language initialization
with the same internal error boundary used for compilation failures. Errors use
the `[TAFFISH-ERROR]` stderr prefix and exit status 1; compiler line, column, and
caret diagnostics are preserved. If stderr or error rendering fails, the process
still exits unsuccessfully without using generated-shell stdout as a fallback.

Library conditions and warnings are not globally suppressed. See
[han.host](../han/host.md) for the implementation-specific interrupt behavior
and the limits of this boundary.

## System Position

```text
user / script
  -> taffish command
  -> taffish-cli
  -> taffish-core
```

## File Responsibilities

| File | Role |
| --- | --- |
| `package.lisp` | Define CLI package. |
| `i18n.lisp` | Own localized human help and common CLI diagnostics. |
| `run.lisp` | Implement main command run logic. |
| `main.lisp` | Provide entry function. |

## Modification Guide

When changing `taffish-cli`, pay attention to:

1. Whether CLI argument changes require completion updates.
2. Whether output format is depended on by scripts or upper tools.
3. Whether errors preserve location information from `taffish-core`.
4. Do not add project, Hub, or install logic here.
5. Verify language selection cannot alter generated shell or core error location data.

If a requirement is a full workflow for ordinary taf-app users, it usually belongs in `taf-cli` and `taf-core`, not `taffish-cli`.
