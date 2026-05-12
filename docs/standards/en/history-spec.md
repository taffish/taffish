# TAFFISH History Specification

This page defines the persistent format of TAFFISH history and the wrapper write contract.

## File Location

The history file is located under user home:

```text
<user-home>/logs/history.jsonl
```

History currently always writes to user home, not system home. Environment variables or wrapper internals may adjust the concrete file path.

## File Format

History uses JSON Lines. Each line is a JSON object.

```json
{"id":"20260510T120000-1A2B","time":"2026-05-10T12:00:00Z","event":"exec","status":"success"}
```

Every record should be independently parseable. Append failure must not affect the main command execution.

## Time And ID

`time` uses UTC:

```text
YYYY-MM-DDTHH:MM:SSZ
```

IDs written by internal Lisp code look like:

```text
<compact-time>-<random-hex>
```

IDs written by wrapper shell look like:

```text
<compact-time>-<pid>
```

Both forms are intended for everyday tracing. Neither promises global uniqueness.

## Common Fields

History events may contain:

| Field | Type | Meaning |
| --- | --- | --- |
| `id` | string | Event id. |
| `time` | string | UTC time. |
| `event` | string | Event type, for example `exec`. |
| `status` | string | `success`, `failure`, or another status. |
| `command` | string | Command or artifact name. |
| `args` | array | Argument list. |
| `cwd` | string | Current working directory. |
| `backend` | string/null | Runtime backend. |
| `exit_code` | number/null | Exit code. |
| `taf_version` | string/null | TAFFISH version information. |

Null fields may be omitted. Readers must not assume that every field exists.

## Project Fields

When an event is project-related, it may contain:

| Field | Type | Source |
| --- | --- | --- |
| `project_name` | string | `[package].name`. |
| `project_kind` | string | `[package].kind`. |
| `project_version` | string | `[package].version`. |
| `project_release` | number/string | `[package].release`. |
| `project_command` | string | `[command].name`. |
| `project_root` | string | Project root or snapshot root. |
| `project_main` | string | Main TAF path. |
| `repository_url` | string/null | `[repository].url`. |
| `container_image` | string/null | `[container].image`. |

## Wrapper-Written Fields

The command wrapper produced by build writes these fields during execution:

| Field | Meaning |
| --- | --- |
| `event` | Fixed to `exec`. |
| `stage` | `compile`, `chmod`, or `run`. |
| `snapshot_root` | Project snapshot used by the wrapper. |
| `history_backend` | Fixed to `shell-wrapper`. |

The wrapper attempts to record history on compile failure, chmod failure, and after command execution.

## Control Variables

The wrapper recognizes:

| Variable | Meaning |
| --- | --- |
| `TAF_HISTORY_MODE` | `async`, `sync`, `off`, or `0`. Defaults to `async`. |
| `TAFFISH_USER_HOME` | Default history home. |
| `TAF_HISTORY_FILE` | Overrides the concrete history file path. |

In `async` mode, history is written in the background and does not block the main command. `sync` mode is for debugging or for cases that require write completion before exit.

## Read Behavior

`taf history` should support:

1. Printing the history file path.
2. Reading the last N lines.
3. Filtering by id.
4. Outputting raw JSONL.
5. Clearing the history file.

The current reader extracts summary fields with lightweight string logic, so the history format should remain simple. If future implementations switch to strict JSON parsing, they should remain compatible with existing JSONL.

## Compatibility Requirements

History is diagnostic and traceability data. It must not become a hard dependency of the main execution path. Write failure should be swallowed as safely as possible.

The following should remain stable long-term:

1. JSONL format.
2. Basic meaning of `id`, `time`, `event`, and `status`.
3. `command`, `args`, `cwd`, and `exit_code` in `exec` events.
4. Wrapper history write failure does not affect command exit code.

