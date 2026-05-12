# Compatibility Policy

This page defines compatibility policy under the TAFFISH specification draft. Its goal is not to stop TAFFISH from evolving, but to make every evolution bounded, migratable, and verifiable.

## Compatibility Targets

TAFFISH needs to protect:

1. Existing `.taf` source files.
2. Existing taf-app project directories.
3. Version records already published to Hub index.
4. Apps and launchers already installed in user TAFFISH homes.
5. Generated command wrappers.
6. Persisted `config.toml`, `install.json`, and `history.jsonl`.

## Conformance Results

Manual checks or future automated conformance tests should return:

| Result | Meaning | Handling |
| --- | --- | --- |
| Pass | Satisfies all MUST items in the current draft. | Can be published, installed, or used as test baseline. |
| Warning | Depends on implementation details, legacy fields, or unstable behavior. | Can continue, but migration risk should be recorded. |
| Fail | Violates MUST items and may break parsing, install, reproduction, or uninstall. | Should not be published; fix project, index, or implementation. |

Conformance is not scientific correctness. A taf-app may fully conform to TAFFISH while still using poor bioinformatics parameters; that belongs to app-layer review.

## Compatibility Priority

Priority from high to low:

| Priority | Object | Reason |
| --- | --- | --- |
| P0 | install and runtime of published taf-apps | users already depend on them. |
| P1 | Hub index schema and query behavior | affects install, search, list, and reproduction. |
| P2 | core `.taf` language semantics | affects all tools and flows. |
| P3 | project build and publish flow | affects developers. |
| P4 | internal APIs and file organization | mostly affects TAFFISH developers. |

## Compatible Changes

Usually allowed:

1. Add optional fields.
2. Add tags or emitters.
3. Add CLI options.
4. Accept broader input without changing meaning of existing input.
5. Improve error messages.
6. Add a new schema version while continuing to read old versions.

## Changes Requiring Migration

These changes must include a migration strategy:

1. Remove or rename existing fields.
2. Change data type of existing fields.
3. Change artifact naming rules.
4. Change default install directories.
5. Change command alias resolution.
6. Change container backend selection order or default mount semantics.
7. Change semantics of existing `.taf` tags.

Migration strategy should explain:

1. How old format is detected.
2. Whether old format remains supported.
3. How users upgrade if it is not supported.
4. Whether an automatic migration tool is needed.
5. Whether `taf doctor` should warn.

## Schema Version Policy

TAFFISH currently uses string schema versions:

| schema | current version | file/output |
| --- | --- | --- |
| hub index | `taffish.index/v1` | `index/current.json` and snapshots. |
| install metadata | `taffish.install/v1` | `apps/<name>/<version-id>/install.json`. |
| config | `taffish.config/v1` | `config.toml`. |
| list JSON output | `taffish.list/v1` | `taf list --json`. |
| which JSON output | `taffish.which/v1` | `taf which --json`. |

When reading persisted files, unknown schema should error instead of being guessed silently. Command-output schemas may evolve independently.

## Deprecation Policy

Deprecating behavior should ideally go through three phases:

1. Keep support and mark as legacy in docs.
2. Emit hints in command output or checks.
3. Remove in the next breaking version.

Current code treats `[container].platforms` as a legacy compatibility field for `[container].build_platforms`. If both exist and disagree, it should error.

## Conformance Test Direction

Future conformance tests should cover at least:

1. Golden outputs for TAF lexer/parser/binder/compiler.
2. `taffish.toml` schema validation.
3. Hub index read/search/resolve/install target parsing.
4. Install metadata read/write and uninstall compatibility.
5. Config merge, index URL resolution, source rewrite.
6. Container backend selection and key generated-shell fragments.

Conformance tests are not required before this draft exists, but they are necessary before `v1.0`.
