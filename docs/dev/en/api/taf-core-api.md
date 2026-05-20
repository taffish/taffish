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

Return:

```lisp
(:project project :command command-result :image image-result)
```

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
                          :release-p nil
                          :remote-tags remote-tags
                          :commit-message message
                          :verbose t)
```

Role: publish a project to GitHub.

Default `dry-run t` means no publication is performed.

Non-dry-run side effects:

1. `git init`.
2. `git remote add`.
3. `git add/commit/tag/push`.
4. Optional `gh repo create`.
5. Optional `gh release create`.

Safety note: TAFFISH does not take over GitHub login. Authentication must be configured externally by the user.

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

Safety note: source URLs are resolved through system config rewrite rules. Installation runs git and build logic.

### `taf.core:hub-install-all`

Stability: stable.

Role: plan or install all indexed apps selected by kind.

Side effects: same as `hub-install` for each package when `yes-p` is true.

Supports `dry-run-p`; dry-run is the expected default at the CLI and MCP
planner layers. Optional `prune-old-p` removes older local versions only after
successful non-dry-run installation.

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

Role: remove older local app versions while keeping the newest local version.

Side effects:

1. Delete older install roots.
2. Delete older artifact launchers.
3. Refresh the unversioned command alias.

Supports `dry-run-p`. It does not remove Docker/Podman/Apptainer images,
Apptainer caches, or SIF files.

### Package Maintenance Output

`hub-install-all`, `hub-outdated`, `hub-upgrade`, and `hub-prune` return or print
the same package-plan structure. JSON output preserves every item. Default text
output is optimized for humans and may suppress `skip` items; if every item is
skipped, it reports `no changes`.

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

### `taf.core:system-doctor`

Stability: stable.

Role: check directories, executables, and PATH status.

Side effects: creates missing directories when `init-p t`. System-scope init requires root.

### `taf.core:system-history`

Stability: stable.

Role: inspect, locate, or clear history JSONL.

Side effects: deletes the history file when `clear-p t`.

### `taf.core:system-record-history-event`

Stability: semi-stable.

Role: append a history event.

Default `safe t` means write failure returns nil and does not interrupt the main flow.

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
| `system-doctor :init-p t` | Creates directories. |
| `system-history :clear-p t` | Deletes history. |

New code calling these APIs should make side-effect permission explicit and prefer dry-run or verbose controls.
