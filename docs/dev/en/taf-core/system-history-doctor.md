# system/history And doctor

`system/history.lisp` records TAFFISH command execution history. `system/doctor.lisp` checks whether the local environment is suitable for running TAFFISH.

## Role Of history

History writes a JSONL file:

```text
logs/history.jsonl
```

It lives under user home by default. Build wrappers write runtime history when executed.

## history event

`system-record-history-event` supports fields:

1. event.
2. status.
3. project.
4. command.
5. args.
6. cwd.
7. backend.
8. exit-code.
9. extra.
10. taf-version.

If a project is passed, it expands:

1. project name.
2. kind.
3. version.
4. release.
5. command.
6. root.
7. main.
8. repository URL.
9. container image.

Default `safe t` means write failure returns nil instead of interrupting the main flow.

## history Query

`system-history` supports:

| Argument | Behavior |
| --- | --- |
| `:last` | Return the last N lines, default 20. |
| `:id` | Filter by id. |
| `:json-p` | Output raw JSONL. |
| `:path-p` | Only output history file path. |
| `:clear-p` | Clear history. |

Current history query uses lightweight string field extraction, not a full JSON parser. This is enough for log browsing, but should not be used for complex analysis.

## Role Of doctor

Doctor checks:

1. Whether required directories exist.
2. Whether directories are writable.
3. Whether required or optional executables exist.
4. Whether command bin is in PATH.

`--init` creates missing directories. System-scope init requires root.

## Executable Checks

Currently checked:

| Program | Requirement |
| --- | --- |
| `git` | required |
| `gh` | optional |
| `docker` | optional |
| `podman` | optional |
| `apptainer` | optional |
| `mksquashfs` | optional |
| `squashfuse` | optional |
| `fuse2fs` | optional |
| `gocryptfs` | optional |
| `taffish` | optional |

`git` is required because publish/install clone and related flows depend on it.

## Doctor Status

Overall doctor status may be:

| Status | Meaning |
| --- | --- |
| `:error` | Error while creating or checking directories. |
| `:needs-init` | Directory or path missing; init needed. |
| `:permission-warning` | Directory or bin not writable. |
| `:missing-tools` | Missing required executable. |
| `:path-warning` | bin is not in PATH. |
| `:ok` | Environment usable. |

## Modification Guide

When changing history/doctor, check:

1. Whether history fields written by build wrappers remain compatible.
2. Whether new directories are synchronized to home required dirs.
3. Whether new external dependencies are added to doctor.
4. Whether doctor status priority gives users correct repair advice.
5. History write failure should not affect normal execution unless strict mode is explicitly requested.

