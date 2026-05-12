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

## Process API

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

Synchronous execution captures stdout/stderr to temporary files and then reads strings back or replays them to streams.

## LispWorks Implementation

LispWorks uses:

1. `sys:*line-arguments-list*`
2. `lw:environment-variable`
3. `lw:quit`
4. `system:run-shell-command`
5. `system:pipe-exit-status`

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

