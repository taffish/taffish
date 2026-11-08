# taf-core API

`taf-core` is the business API behind the `taf` command. It covers project, Hub, and system capabilities. Many functions read and write files, run external commands, operate git, or install apps.

## Default Variables

Stability: semi-stable.

| Variable | Meaning |
| --- | --- |
| `*default-github-host*` | Default GitHub host, currently `github.com`. |
| `*default-github-owner*` | Default GitHub owner, currently `taffish`. |
| `*default-container-registry*` | Default container registry, currently `ghcr.io`. |
| `*default-docker-base-image*` | Default base image for `taf new --docker`. |
| `*default-index-repository*` | Default index repository. |
| `*default-index-branch*` | Default index branch. |

These variables affect default repositories, images, and index URLs. Changing them affects new projects and default Hub behavior.

## Project API

### `taf.core:project-new`

Stability: stable.

```lisp
(taf.core:project-new name args)
```

Role: create a taf-app project skeleton.

Side effects: creates directories and files.

Return: currently reports mainly through stdout; return value is not a stable contract.

Common errors:

1. Invalid project name.
2. Target directory already exists.
3. Invalid version, release, license, or repo.

### `taf.core:project-check`

Stability: stable.

```lisp
(taf.core:project-check &optional start-dir verbose dependency-check-p)
```

Role: find the project root, read `taffish.toml`, check the main TAF file, and return a project plist.

Return fields include:

```text
:root-dir :toml-file :name :kind :version :release :license
:repository-url :command-name :main-path :main-file :help-file
:target-dir :runtime-pipe :runtime-command-mode :container-image
:dependencies :smoke :dockerfile :container-build-platforms
```

Side effects: prints a summary when verbose by default; does not modify files.

### `taf.core:project-compile`

Stability: stable.

```lisp
(taf.core:project-compile &optional args start-dir &rest options)
```

Role: compile the project's main TAF file and return a shell string.

Supported option:

```lisp
:container-backend
```

Side effects: no file writes, but detects external commands and CPU count.

### `taf.core:project-run`

Stability: stable.

```lisp
(taf.core:project-run :args args
                      :start-dir start-dir
                      :container-backend backend
                      :input input
                      :output output
                      :error-output error-output)
```

Role: compile project TAF into a temporary shell script and run it.

Side effects: creates and cleans up a temporary directory, executes shell.

Return:

```lisp
(:exit-code code :stdout stdout :stderr stderr)
```

### `taf.core:project-build`

Stability: stable.

```lisp
(taf.core:project-build :command-p t
                        :image-p nil
                        :backend backend
                        :user-home user-home
                        :system-home system-home
                        :start-dir start-dir
                        :verbose t)
```

Role: build a command wrapper and optional container image.

Side effects:

1. Writes `target/`.
2. Copies a source snapshot.
3. Runs chmod on the wrapper.
4. May rewrite `[dependencies]` for flow projects.
5. Runs Docker or Podman build when `:image-p t`.

Command-wrapper output is content-addressed through a private build manifest.
An unchanged valid wrapper/snapshot returns without rewriting either artifact;
rebuild replacement is staged and rolls back to the last valid pair on failure.

Return:

```lisp
(:project project :command command-result :image image-result)
```

The command plist preserves its existing fields and additively reports
`:status`, `:source-sha256`, `:wrapper-sha256`, and `:manifest-file`.

### `taf.core:project-publish`

Stability: semi-stable.

```lisp
(taf.core:project-publish :start-dir start-dir
                          :dry-run t
                          :build-p nil
                          :channel :latest
                          :prompt-p nil
                          :create-repo-p nil
                          :repo-visibility :public
                          :lock-repo-p t
                          :release-p nil
                          :remote-tags remote-tags
                          :commit-message message
                          :verbose t)
```

Role: publish a project to GitHub.

Default `dry-run t` means no publication is performed.

Publication is version-order-independent: it does not require the current
version to exceed an earlier one. With `:release-p t`, `:channel :latest`
(the default) creates a formal GitHub Release marked Latest; `:pre` creates a
GitHub prerelease without setting Latest; `:no-latest` creates a formal Release
without setting Latest. With `:release-p nil`, publication remains tag-only.

Non-dry-run side effects:

1. `git init`.
2. `git remote add`.
3. `git add/commit/tag/push`.
4. Optional `gh repo create`.
5. Optional `gh release create`.
6. Writes a publish journal under the TAFFISH user home.

Safety note: TAFFISH does not take over GitHub login. Authentication must be configured externally by the user.

Publication uses an inspect/ensure state machine. Repeating the same call after
an interruption resumes matching partial state, while conflicting commit, tag,
repository, policy, or Release identities fail without overwrite. The result
keeps the legacy fields and additionally reports `:outcome`, `:phases`,
`:resumed-p`, `:complete-p`, `:journal-file`, `:warnings`, and `:build-status`.
With `:build-p t`, build is ensured before commit and is skipped after a
matching release commit/tag identity is established.

Retry with the same channel and release intent. A matching existing Release is
not edited and does not reclaim Latest from a later publication. The legacy
`:remote-latest` result is only a remote-tag sorting diagnostic, not the GitHub
Latest designation, and is not used to allow or reject publication.

## Hub API

### `taf.core:hub-update`

Stability: stable.

Role: download or read an index and write `index/current.json` plus a snapshot.

Side effects: writes index files, may access the network or read a local file.

Return: a plist containing `:scope`, `:home`, `:source`, `:current-file`, `:snapshot-file`, `:timestamp`, and `:bytes`.

### `taf.core:hub-info` / `hub-info-many`

Stability: stable.

Role: resolve package, command, or artifact queries from the local index.

Side effects: prints results when verbose by default; does not modify files.

Return: resolution plist containing `:package-name`, `:version-id`, `:record`, and related fields.

### `taf.core:hub-search`

Stability: stable.

Role: search the local index.

Return: plist containing `:query`, `:terms`, `:total`, and `:matches`.

### `taf.core:hub-install` / `hub-install-many`

Stability: stable.

Role: install Hub apps.

Side effects:

1. Clone or copy source.
2. Call `project-build`.
3. Write install root.
4. Write launcher.
5. Write install metadata.
6. Recursively install dependencies.

Supports `dry-run-p`. Dry-run should not write files.

Optional `:repair-p` defaults to `nil`. With `t`, these APIs preflight the whole
selected set read-only and rebuild only existing indexed identities whose
source, identity, managed paths and fixed source commit pass repair checks.
Verified targets are skipped. Any blocked target prevents batch writes; absent
explicit targets, unknown schemas, private sources and custom launchers are
blocked. Repair does not recursively install dependencies and rejects `:force-p`;
the single-target API also rejects caller-supplied `:record` in repair mode.
Use `:dry-run-p t` to preview; explicit single/multiple repair otherwise applies.
The opt-in result is `taffish.repair-plan/v1`; ordinary-call results are unchanged.
See [repair policy](../taf-core/hub-maintenance.md#explicit-repair) for staging,
backups, validation, rollback and interrupted-journal limits. No MCP repair
parameter or execution entry is added.

Safety note: source URLs are resolved through system config rewrite rules. Installation runs git and build logic.

### `taf.core:hub-install-all`

Stability: stable.

Role: plan or install all indexed apps selected by kind.

Side effects: same as `hub-install` for each package when `yes-p` is true.

Supports `dry-run-p`; dry-run is the expected default at the CLI and MCP
planner layers. Optional `prune-old-p` removes older local versions only after
successful non-dry-run installation.

By default, `:repair-p t` selects only already-installed index.latest identities
within `:kind` and `:scope`. Truly absent identities are counted and skipped;
existing roots with damaged metadata are blocked. It neither upgrades other
versions nor installs missing apps/dependencies. Use an explicit `hub-install`
target with `:version-id` for one older identity, or `:all-installed-p t` for
all installed versions. Repair rejects `:force-p` and
`:prune-old-p`; it previews unless `:yes-p t` and `:dry-run-p nil`. It uses the
same all-target preflight and `taffish.repair-plan/v1` result as above.

`:all-installed-p` defaults to `nil` and requires `:repair-p t`. With `t`, targets
come from all installed local versions rather than index.latest. Missing or
unresolvable records remain blocked. Kind/scope filtering, preview/yes, and the
existing safety preflight still apply. The repair result adds `selection` with
`index-latest`, `installed-all-versions`, or `explicit`; existing fields and
ordinary-install results are unchanged.

### `taf.core:hub-outdated`

Stability: stable.

Role: compare local install metadata with the local index and report outdated,
current, ahead, missing-index, local-project, or not-installed states.

Side effects: prints when verbose by default; does not modify files.

### `taf.core:hub-upgrade`

Stability: stable.

Role: plan or install newer indexed versions for locally installed apps.

Side effects: same as `hub-install` for outdated packages when `yes-p` is true.
Local/private `local-project` installs are skipped.

Supports `dry-run-p`; dry-run should not write files.

### `taf.core:hub-prune`

Stability: stable.

Role: remove reliably older same-source versions while retaining a valid installed
index.latest. Missing or invalid targets are skipped; private/unknown/conflicting
origins and newer or ambiguously ordered identities are protected.

Side effects:

1. Delete older install roots.
2. Delete older artifact launchers.
3. Refresh the unversioned command alias.

Supports `dry-run-p`. It does not remove Docker/Podman/Apptainer images,
Apptainer caches, or SIF files.

### Package Maintenance Output

Ordinary `hub-install-all` (without repair), `hub-outdated`, `hub-upgrade`, and `hub-prune` return or print
the same package-plan structure. JSON output preserves every item. Default text
output suppresses healthy unchanged items, but still shows validation warnings
and missing-target/source blockers. A version can be current while its integrity
is unverified. With no changes, warnings or blockers, it reports `no changes`.

Repeated diagnostics are grouped by issue type/state and policy within the scope,
with counts and at most three examples per group; repeated skip rows are omitted.
The complete structured evidence remains available. Human stderr progress uses
TTY in-place stages/counts and rate-limited log lines. `:verbose nil`, JSON and
MCP suppress progress; probe caches are local to a read-only scan, not mutations.

Online targets follow index.latest, never a locally recomputed maximum.
An exact valid target is current even when a newer local version also exists;
maintenance does not automatically downgrade. See the [Hub version policy](../taf-core/hub-system.md#version-selection-and-safe-pruning).

### `taf.core:hub-uninstall` / `hub-uninstall-many`

Stability: stable.

Role: uninstall local apps.

Side effects:

1. Delete install root.
2. Delete artifact launcher.
3. Delete or refresh command alias.

Supports `dry-run-p`.

### `taf.core:hub-list`

Stability: stable.

Role: list local installations or local index content.

Modes:

```text
:local / :installed
:online / :index
```

Supports JSON output, with JSON schema `taffish.list/v1`.

### `taf.core:hub-which` / `hub-which-many`

Stability: stable.

Role: locate paths for installed apps, including launcher, command file, source, and metadata.

Supports JSON output, with JSON schema `taffish.which/v1`.

## System API

### `taf.core:system-config`

Stability: stable.

Role: return the current effective config, home, bin, index, images, cache, and related paths.

Side effects: prints when verbose by default; does not write files.

### `taf.core:system-config-path`

Stability: stable.

Role: return active/user/system/explicit config file paths.

### `taf.core:system-config-init`

Stability: stable.

Role: write a config template.

Side effects: creates or overwrites config files. System scope requires root.

Profiles:

```text
:github
:china
```

### `taf.core:system-config-language`

Stability: additive public API.

Role: inspect configured/displayed language details and available built-in or
external locale packs, or update the selected scope's top-level `language`
field.

Side effects: read-only when `:language` is nil; otherwise preserves all
non-language config text while writing the selected config file. System scope
requires root. External language IDs must be present in current discovery.

### `taf.core:system-doctor`

Stability: stable.

Role: return legacy directory/executable/PATH checks plus structured diagnostics
for config, index, command paths, shell completion, Vim/Neovim, Apptainer SIF
policy, and bounded container-backend readiness.

Additive controls:

```lisp
:shell :auto|:bash|:zsh|:fish
:detail-p boolean
:json-p boolean
:check :environment|:index|:hub
:targets list-of-strings
```

The result preserves `:status`, `:directories`, `:executables`, and `:paths`,
and adds `:diagnostic-status` and `:diagnostics`. Rendering is controlled by
`:verbose`; JSON uses schema `taffish.doctor/v1`.

Default Hub text uses bounded issue/policy summaries (at most three examples per
group); `:detail-p t` corresponds to CLI `--verbose` and retains full inspections.
`:verbose` controls rendering, not evidence completeness. Returned plists and
JSON retain all diagnostics. Hub scans batch read-only probes; human progress is
stderr-only, TTY in-place or rate-limited for logs, and absent from JSON/MCP.

`:check` defaults to `:environment`. `:index` and `:hub` are offline, read-only
checks with additive `:check` / `:exit-code` and per-item `:inspection` evidence.
Only `:hub` accepts `:targets` (app or command names); specialized checks reject
init and non-default shell selection. Exit code 1 means invalid/unknown checks,
0 includes warnings. Returned legacy fields remain present; skipped default
environment groups have empty lists. See [doctor contract](../taf-core/system-history-doctor.md).

Side effects: none by default. It creates missing TAFFISH-owned directories
only when `init-p t`. System-scope init requires root. It never edits shell or
editor configuration, changes permissions, starts services, pulls images, or
runs containers.

### `taf.core:system-history`

Stability: stable.

Role: inspect, locate, or clear history JSONL.

Side effects: deletes the history file when `clear-p t`.

### `taf.core:system-record-history-event`

Stability: semi-stable.

Role: append a history event.

Default `safe t` means write failure returns nil and does not interrupt the main flow.

The internal adapter `system-record-wrapper-history` accepts a destination path
and the generated wrapper's field stream. It uses the same locked append as
native events. See the [history contract](../../../standards/en/history-spec.md).

## API Call Safety Table

| API | Main side effects |
| --- | --- |
| `project-new` | Creates project files. |
| `project-run` | Executes generated shell. |
| `project-build` | Writes target and may build an image. |
| `project-publish` | Performs git/gh publication operations. |
| `hub-update` | Writes index and may access the network. |
| `hub-install` | Clones/copies/builds/writes launchers. |
| `hub-install-all` | May clone/copy/build/write many launchers when `yes-p` is true. |
| `hub-upgrade` | May install newer app versions when `yes-p` is true. |
| `hub-prune` | Deletes older local install roots and launchers when `yes-p` is true. |
| `hub-uninstall` | Deletes install directories and launchers. |
| `system-config-init` | Writes config. |
| `system-config-language :language <value>` | Narrowly updates the top-level language field; system scope requires root. |
| `system-doctor :init-p t` | Creates directories. |
| `system-history :clear-p t` | Deletes history. |

New code calling these APIs should make side-effect permission explicit and prefer dry-run or verbose controls.
