# han.host Host Adaptation Layer

`han.host` is the lowest host-implementation adaptation layer in han. It hides differences between Common Lisp implementations such as SBCL and LispWorks.

## Role

TAFFISH builds binary command-line tools, so upper layers should not contain `#+sbcl`, `#+lispworks`, and similar conditional code everywhere. `han.host` centralizes those differences.

## Supported Implementations

Currently declared support:

```text
SBCL, LispWorks
```

Unsupported implementations load `unsupported.lisp`; calling related functions signals `unsupported-host-function`.

## Common Capabilities

`common.lisp` provides:

1. Unified `host-process` structure.
2. cwd.
3. File existence and directory existence checks.
4. Directory file and subdirectory enumeration.
5. copy-file.
6. delete-directory-tree.
7. temporary-directory.
8. POSIX shell token escaping.
9. Temporary input/output file mechanism needed by synchronous process execution.

## Runtime I/O And Terminal Detection

| API | Role |
| --- | --- |
| `configure-runtime-io` | Configure implementation-specific character I/O before a delivered CLI handles user text. LispWorks selects UTF-8 console I/O; SBCL currently needs no extra setup. |
| `standard-input-terminal-p` | Report whether file descriptor 0 is a terminal, so commands can distinguish interactive stdin from an actual pipe. |
| `standard-error-terminal-p` | Query whether process stderr (file descriptor 2) is a terminal, without reading, writing or spawning a process. |
| `append-utf8-line` | Append UTF-8 bytes and a newline, retrying short writes. |
| `call-with-exclusive-file-lock` | Hold an OS lock on the given stable path while running a zero-argument function. The default wait is five seconds. |

These functions are host-specific by design. Upper layers must not reproduce
SBCL/LispWorks terminal checks or console encoding setup directly.

`standard-error-terminal-p` queries fd 2, not a dynamically rebound
`*error-output*`. On supported hosts, closed/non-terminal descriptors return
false; unsupported implementations signal `unsupported-host-function`.
It is not a terminal-size or cursor-capability query. Progress callers separately
check the actual output stream and `TERM=dumb` before using in-place rendering;
redirected logs use rate-limited lines. JSON/MCP callers suppress human progress.
The LispWorks UTF-8 output stream implements `interactive-stream-p` from its
live descriptor; a terminal, pipe, and closed stream must remain distinguishable.

Concurrent JSONL writers hold the same exclusive lock across the complete
`append-utf8-line` call, including any short writes.
The append helper creates a missing parent directory and tolerates the specific race where
another process creates that same parent first. Other path and permission
errors still propagate from directory preparation or the append operation.

## Process API

### Executable Error Boundary

The three CLI entry points use a private host error boundary around runtime I/O
and language initialization. Escaping errors are reported to stderr with the
command's existing error prefix and exit status 1. If stderr or the condition's
printer fails, reporting is best-effort and the command still exits unsuccessfully;
it never uses stdout as an error fallback, including in MCP stdio mode.

SBCL interactive interrupts are handled at this boundary without a runtime
backtrace, retaining exit status 1. LispWorks retains its existing interrupt
handling, including its fixed `Interrupted - quitting` stdout notification on
SIGINT. The CLI does not replace global LispWorks signal handlers.
SIGTERM behavior is not changed. This is not a guarantee for native
crashes or exhausted runtime resources.

The boundary is internal, not an exported han API. It does not suppress warnings,
change library condition handling, or alter ordinary CLI/MCP response contracts.

### Process Operations

| API | Role |
| --- | --- |
| `run-program` | Start an external process and return `host-process`. |
| `run-program-sync` | Run a command synchronously and return stdout, stderr, exit-code. |
| `process-status` | Return `:running`, `:exited`, or `:unknown`. |
| `process-exit-code` | Get exit code. |
| `process-wait` | Wait for process completion. |
| `process-close` | Close related streams/resources. |

## SBCL Implementation

SBCL uses:

1. `sb-ext:*posix-argv*`
2. `sb-ext:posix-getenv`
3. `sb-ext:exit`
4. `sb-ext:run-program`
5. `O_APPEND` with `write(2)` for complete UTF-8 log records

Synchronous execution captures stdout/stderr to temporary files and then reads strings back or replays them to streams.

## LispWorks Implementation

LispWorks uses:

1. `sys:*line-arguments-list*`
2. `lw:environment-variable`
3. `lw:quit`
4. `system:run-shell-command`
5. `system:pipe-exit-status`
6. C append mode plus direct UTF-8 byte writes for complete log records

It also returns through the unified `host-process` wrapper.

## Safety Details

`delete-directory-tree` refuses to delete unsafe directories such as `/`. Actual deletion uses system `rm -rf`, but it is preceded by validation.

`escape-sh-token` uses single-quote quoting and handles internal single quotes correctly:

```sh
'abc'\''def'
```

## Modification Guide

Be very careful when changing the host layer:

1. Do not introduce TAFFISH business logic.
2. Check SBCL and LispWorks together.
3. Preserve process return semantics.
4. Do not weaken directory deletion safety checks.
5. Shell escaping behavior affects TAFFISH security as a whole.
6. Recheck delivered CLI stdin and non-ASCII diagnostics on both release hosts.
