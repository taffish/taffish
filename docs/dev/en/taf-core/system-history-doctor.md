# system/history And doctor

`system/history.lisp` records TAFFISH command execution history.
`system/doctor.lisp` provides read-only-first diagnostics for the local TAFFISH
environment.

## Role Of history

History writes a JSONL file under the active user home:

```text
logs/history.jsonl
```

Build wrappers write runtime history when executed.

`system-record-history-event` accepts event, status, project, command, args,
cwd, backend, exit code, extra metadata, and the taf version. Project input is
expanded into name, kind, version, release, command, root, main path,
repository URL, and container image. With the default `safe t`, a history
write failure returns nil instead of interrupting execution.

`system-history` supports:

| Argument | Behavior |
| --- | --- |
| `:last` | Return the last N lines, default 20. |
| `:id` | Filter by id. |
| `:json-p` | Output raw JSONL. |
| `:path-p` | Only output the history file path. |
| `:clear-p` | Clear history. |

History query uses lightweight string field extraction, not a full JSON
query engine.

## Role Of doctor

Doctor diagnoses eight groups:

1. TAFFISH home directories and permissions.
2. Effective config parsing.
3. The local index snapshot.
4. Core command and app command paths.
5. Bash, Zsh, or Fish completion installation and detectable activation.
6. Vim/Neovim runtime files and detectable activation.
7. User/system Apptainer SIF cache policy.
8. Bounded Docker, Podman, and Apptainer readiness probes.

The CLI is:

```text
taf doctor [--user | --system] [--init]
           [--shell auto|bash|zsh|fish]
           [--json | --verbose]
```

Default text is concise and prints only actionable or uncertain diagnostics.
`--verbose` adds evidence, remediation, and documentation URLs. `--json`
emits stable English field names under schema `taffish.doctor/v1`.

## Diagnostic Contract

Every item has the additive structure:

```lisp
(:id ...
 :status :ok|:warning|:error|:unknown|:not-applicable
 :scope :user|:system
 :summary ...
 :evidence ...
 :remediation ...
 :docs-url ...)
```

`system-doctor` preserves the original `:directories`, `:executables`,
`:paths`, and legacy `:status` fields. It adds `:diagnostics` and
`:diagnostic-status`. JSON converts hyphens to underscores, so diagnostic ids
such as `:shell-completion` become `shell_completion`.

Diagnostic statuses mean:

| Status | Meaning |
| --- | --- |
| `:ok` | The applicable check passed. |
| `:warning` | Usable or recoverable state needs attention. |
| `:error` | The selected policy is unsafe or unusable. |
| `:unknown` | Installed state exists, but activation/readiness cannot be proven. |
| `:not-applicable` | The capability is not installed or relevant. |

Unknown is intentionally different from success. For example, installed
completion source files do not prove that the current shell loaded them.

## Executable And Backend Checks

`git` remains required. `gh`, container backends, squashfs helpers, `taf`,
`taffish`, Vim, and Neovim are capability checks. Docker, Podman, and
Apptainer readiness commands run with stdin disabled and a short timeout.
Doctor never starts a daemon, creates a Podman machine, pulls an image, or runs
a container.

## Apptainer SIF Policies

Doctor recognizes these valid policies:

1. A writable per-user SIF cache.
2. A writable system cache with mode `1777` and the sticky bit.
3. A readable administrator-prefilled system cache plus a writable user
   fallback.

A world-writable system cache without the sticky bit is an error. Doctor
reports permissions but never runs `chmod`, `chown`, or `sudo`.

## Side-Effect Boundary

Doctor is read-only unless `:init-p t` / `--init` is explicit. Initialization
only creates TAFFISH-owned required directories. It does not edit shell rc
files, Fish configuration, Vim/Neovim configuration, system configuration,
ownership, permissions, daemons, or container state. System-scope init still
requires root.

## API Controls

`system-doctor` accepts additive keyword controls:

| Argument | Behavior |
| --- | --- |
| `:shell` | `:auto`, `:bash`, `:zsh`, or `:fish`. |
| `:detail-p` | Include detailed evidence in human output. |
| `:json-p` | Render `taffish.doctor/v1` JSON when output is enabled. |
| `:verbose` | Enable or suppress rendering; the result plist is always returned. |

## Modification Guide

When changing history or doctor, check:

1. History fields written by build wrappers remain compatible.
2. New home directories remain synchronized with the required-dir list.
3. Diagnostics preserve the unified item schema and legacy result fields.
4. Probes remain bounded, non-interactive, and free of repair side effects.
5. CLI help, completion, MCP projection, tests, and both language docs remain synchronized.
6. Process/path/permission changes receive macOS/SBCL and Linux/LispWorks verification.
