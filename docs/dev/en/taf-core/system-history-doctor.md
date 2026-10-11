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

Each event receives a process-aware unique ID and is appended as one UTF-8
JSONL record through `han.host`. Concurrent `taf` processes therefore do not
reuse IDs or overwrite one another's records, including when several first
writers race to create the history directory.

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

History headers, labels, empty-state text, and clear results use the resolved
human language. Raw JSONL output, event fields, IDs, statuses, commands, and
stored records remain language-invariant.

## Role Of doctor

The default environment check diagnoses eight groups, without hashing all apps:

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
Recovery advice is included for problems even in concise mode. `--verbose`
adds detailed evidence and documentation URLs. `--json`
emits stable English field names under schema `taffish.doctor/v1`.

Human text follows the resolved `taffish.i18n` language and has built-in
English/Chinese summaries and remediation. The diagnostic plist and `--json`
payload deliberately retain canonical English ids, status values, evidence,
and machine fields; localization never changes detector logic.

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

## Offline Index And Installation Checks

```sh
taf doctor index --user
taf doctor hub --system
taf doctor hub APP taf-APP-v1.4.0-r1 --user --verbose
taf doctor hub APP --user --json
```

`index` reads the selected local `index/current.json`: readability, JSON/schema,
package structure, latest references and selected-record identity. It never
downloads a replacement. Missing index is a warning; malformed data is an error;
unsupported schema or unreadable evidence is unknown.

`hub` adds installed-app checks in that scope. Targets may be app names, base
commands or versioned commands; no targets checks all installations. It reports
broken `install.json` records instead of silently dropping them, and can check
local files even without an index. It validates required wrappers/launchers,
frozen project files, identity and `.taf-build.json` hashes. Links and permissions
are checked before reading snapshot content; unsafe or unsupported links are
reported as unknown, never executed. The scanner uses local `test` and BSD/GNU
`find` utilities, not a shell evaluation of app input.

Each installation has `inspection.state`: `verified`, `unverified`, `invalid`,
or `unknown`, mapped to diagnostic `ok`, `warning`, `error`, or `unknown`.
Missing old manifests and unfamiliar launcher templates are unverified when
required structure is intact. Missing required files and inconsistent hashes
are invalid. `issues` contains stable codes, paths and optional detail; an empty
list may be JSON `null`. Version/source status is separate: `index_latest` and
`source_status` are evidence in verbose/JSON output, not authenticity claims.
Verified local files do not establish official origin or container readiness.

Installation paths must agree with the managed directory layout. Inconsistent
paths or an unsupported `install.json` schema are `unknown`; a missing schema
declaration in a legacy record is `unverified`. Neither permits automatic pruning.
An absent `apps` directory means no installations, but a file, link or unreadable
directory at that location is reported instead of treated as empty.

The unversioned command shortcut is checked separately as `hub_command`.
A missing or unfamiliar shortcut produces a warning without changing the
`hub_installation` integrity result. With several versions installed, the shortcut
is compared with the local alias selection, not required to point to every version.
Doctor never executes or rewrites the shortcut. `--verbose` shows evidence as JSON.

Default Hub text groups repeated issues by type/state and recovery policy within
the selected scope, with counts and at most three examples per group. Advice is
not repeated for every app. `--verbose` and `--json` retain every inspection and
its full evidence; rendering a summary does not remove items from the result.

Use the reported scope and paths to decide recovery. Back up local edits and
preview `taf install APP VERSION-ID --repair --user --dry-run` (or `--system`), then review
the safety classification. Specify the exact version for an older installation.
Doctor never invokes repair or writes missing manifests. Repair rejects private
sources, custom launchers and unknown schemas; permissions and compatibility
still require owner review. See [explicit repair](hub-maintenance.md#explicit-repair)
for all-target selection, no-write preflight and transaction limits.

Specialized checks reject `--init` and `--shell`, never probe backends, and never
execute apps, access the network, alter files, or repair permissions. They add
`check` and `exit_code` to `taffish.doctor/v1`: exit 1 for error/unknown findings,
otherwise 0 (including warnings). JSON is still returned on a failed check.
The default environment check's existing exit behavior is unchanged.

Hub diagnostics reuse batched path, directory and alias evidence across one
read-only scan while retaining manifest checksum checks. There is no persistent
verification cache. `taf doctor hub APP` filters targets before deep inspection;
alias checks may read sibling-version metadata to determine the local shortcut.
Unknown schemas and unsafe paths do not trigger deep traversal. A blocked target
scan reports unknown rather than falsely claiming the target is absent.
Human stderr reports stages/counts in place on a TTY and rate-limited lines in
logs, as described in [batch maintenance](hub-maintenance.md#planning-performance).
JSON and MCP remain progress-free. Shared conservative Unicode field layout
falls back to separate lines for long or complex text, not language-specific
spaces or truncated paths.

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
| `:check` | Default `:environment`; `:index` or `:hub` selects offline checks. String equivalents are accepted. |
| `:targets` | Optional list of nonempty strings, only with `:check :hub`. |

## Modification Guide

When changing history or doctor, check:

1. History fields written by build wrappers remain compatible.
2. New home directories remain synchronized with the required-dir list.
3. Diagnostics preserve the unified item schema and legacy result fields.
4. Probes remain bounded, non-interactive, and free of repair side effects.
5. CLI help, completion, MCP projection, tests, and both language docs remain synchronized.
6. Process/path/permission changes receive macOS/SBCL and Linux/LispWorks verification.
7. Human translations and stable-English JSON receive separate regression tests.


### Interpreting Hub Counts

The human report separates enumerated apps/version identities from affected
apps/version identities and issue counts. One identity can have several issues.
Unreadable or unsafe paths produce an incomplete-inspection notice; enumerated
counts are not a claim of complete verification. `--verbose` and JSON retain
full evidence. A missing legacy build manifest means unverified, not damaged.

To include historical versions in a repair preview, use
`taf install --all-installed --repair --user` (or `--system`). Add `--yes` only
after reviewing the complete plan. `--all --repair` still selects installed
index.latest only. Doctor itself never performs either repair.
