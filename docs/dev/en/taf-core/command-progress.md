# Command Status and Progress

Slow human-facing operations report status on **stderr**. Final results remain
on stdout. No extra option is required.

| Command | Status shown |
| --- | --- |
| `taf update` | Downloading or reading the index, then checking and saving it. |
| `taf install`, `taf upgrade` | Current changed target, source retrieval, command build, and validation. |
| `taf install --repair` | Initial scan, rechecking the plan under the write lock, then each target's retrieval, build, validation, and installation switch. |
| `taf prune`, `taf uninstall` | Checking candidates and removing a selected installed version. A preview never reports an actual removal. |
| `taf publish` | Repository/protection/commit/branch/tag/Release checks, existing query retries, and confirmation after a write. A dry-run never reports executing a publish step. |
| `taf build` | Snapshot, wrapper, and validation stages when the operation has already taken about a second. Image builds retain the backend's own output. |

## Reading the Display

For example, `Getting source | taf-example-v1.0.0-r1 | 2/5` identifies the
**second target being processed**, not two successfully completed targets and
not 40% of the elapsed time. Final command summaries report actual results.
Dependency work can occur within its parent's target count.

On an interactive stderr terminal, short supported text is updated in place.
The status line ends before normal results or streamed subprocess output, and
on success or failure. Redirected output and `TERM=dumb` use ordinary lines.
Logs suppress rapid repeated stages; a new target or an explicit query retry
can produce a line immediately. Long or uncertain-width text also uses lines
instead of cursor updates. Labels/targets in status lines are bounded and
control characters are sanitized; full identities remain in command results.
The display budget is at most 78 columns, reduced when `COLUMNS` specifies a
smaller width. It does not query or continuously track terminal window size.

Updates happen at **operation boundaries**, not on a background timer. A long
synchronous download, filesystem operation, or remote query can leave the same
stage visible until it returns. There is no invented percentage, ETA, timeout,
or heartbeat guarantee. Status is not proof that a remote operation succeeded.
Native Git or container output can still provide its own details.

## Stable Interfaces

- JSON and MCP calls do not emit these notices. A top-level core call with
  `:verbose nil` stays silent. Nested silent helpers can share the human
  caller's display without printing their normal result summaries.
- Fast queries, compiled shell output, `taf run`, and app stdout are not given
  progress decorations. Do not merge stderr into stdout when consuming results.
- Status-output failures disable status without changing the operation result.
- Status does not control retries, timeouts, validation, locking, repair,
  deletion, or publish reconciliation. All existing safety checks still apply.
- Built-in English and Chinese use the shared language setting. External
  `messages.json` catalogs may override `taf.progress.*` keys; missing entries
  use the normal language fallback. No configuration or machine schema changes.

The internal implementation is `taf-core/progress.lisp`. It exposes no new
public API and uses the existing host terminal probe and conservative display
width helper. See [external tests](../../../../test/README.md) for offline
delivered-binary coverage.
