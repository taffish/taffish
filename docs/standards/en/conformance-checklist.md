# TAFFISH Conformance Checklist

This page is for manually checking whether a `.taf` file, a taf-app project, a Hub index, or a local installation conforms to TAFFISH Specification Draft v0.1. It is not an automated test suite, but it should be treated as the blueprint for future conformance tests.

## Result Classes

| Result | Meaning |
| --- | --- |
| Pass | Satisfies all required items and does not clearly rely on unstable behavior. |
| Warning | Satisfies the required items but relies on legacy fields, current implementation details, or unstable behavior. |
| Fail | Violates required items and may cause parsing, build, install, runtime, or uninstall failures. |

Recommended inspection record:

```text
target:
scope:
result: pass/warning/fail
checked_at:
notes:
```

## `.taf` File Checks

### Required

- The file is not empty.
- The main structure contains at most one `ARGS` block and one `RUN` block.
- If `ARGS` exists, it appears before `RUN`.
- A `RUN` block exists, or the file can be normalized into a file with a `RUN` block.
- Every non-empty runtime subtag has content.
- `ARGS` subtag headers do not contain `::...::` parameter tokens.
- All `::...::` parameter tokens are closed.
- Ordinary parameters that are not declared and do not have defaults are not used in code.
- Built-in parameters use only reserved names, such as `*USER*`, `*HOMEDIR*`, and `*WORKDIR*`.
- Subtags are recognized by an emitter, or are explicitly documented as experimental extensions.

### Recommended

- Complex files should write `RUN` explicitly instead of relying on bare-code normalization.
- Complex tools should write `ARGS` explicitly so parameter entry points are readable.
- Shell quoting around parameter tokens should be clear and reviewable.
- Container image references should use explicit tags rather than implicit `latest`.
- `[[taf:...]]` dependency references in flows should be synchronizable back to `[dependencies]`.

### Warnings

- Uses the `<taffish>` inline composition syntax.
- Uses `taf-app` command mode.
- Uses dynamic parameter tokens in subtag headers.
- Uses `$RUN-ARGS` in a container tag to pass complex shell fragments.

## taf-app Project Checks

### Required

- The project root contains `taffish.toml`.
- `[package].name` is non-empty, contains only ASCII letters, digits, `-`, and `_`, and does not start with `-` or `.`.
- `[package].kind` is `tool` or `flow`.
- `[package].version` is non-empty and contains no space or tab.
- `[package].release` is a positive integer.
- `[package].main` is a project-relative path to a `.taf` file.
- `[repository].url` is a canonical GitHub repository URL.
- `[command].name` starts with `taf-`.
- `[runtime].pipe` and `[runtime].command_mode` are booleans.
- `docs/help.md` exists.
- The main `.taf` file can be parsed.
- If `[container].dockerfile` exists, the path stays inside the project and the file exists.
- If `[container].image` exists, its image tag equals `<version>-r<release>`.
- If `[container].image` exists, the static container image in the main `.taf` file matches it.
- If `[container].image` or `[container].dockerfile` exists, valid `[smoke]` metadata exists.
- `[smoke].backend`, when present, is `docker`, `podman`, or `apptainer`.
- `[smoke].timeout`, when present, is a positive integer.
- `[smoke].exist` and `[smoke].test`, when present, are string arrays, and at least one of them is non-empty.
- `[smoke].exist` and `[smoke].test` do not contain default `TODO` placeholders.
- If the project is a flow, `[[taf:...]]` dependencies in the main `.taf` file are declared in `[dependencies]` or can be synchronized by `taf build`.

### Recommended

- `README.md` should describe what the app does.
- `LICENSE` should exist and should not be a placeholder.
- `release.md` should exist before release, with a clear release summary on the first line.
- Tool projects usually set `pipe = true` and `command_mode = true`.
- Flow projects usually set `pipe = false` and `command_mode = false`.
- Containerized tools should provide both a Dockerfile and an explicit image.
- `[dependencies]` should prefer exact version ids instead of long-term `latest` dependencies.
- Public Hub candidates should add `[meta]` with domain, category, summary, and keywords for discovery.
- Tool apps wrapping third-party software should add `[upstream]` with upstream name, version, URL, open-source license, citation, DOI, and PMID when available.

### Warnings

- Uses legacy `[container].platforms`.
- Uses `latest` or `*` in `[dependencies]`.
- Mixes canonical repository URLs with mirror source identities.
- Public Hub candidate lacks `[meta]`, or a third-party tool wrapper lacks `[upstream]`.
- `release.md` still keeps the default release placeholder, or `README.md` still contains unfinished TODO-like placeholders.

## Hub Index Checks

### Required

- The top-level value is a JSON object.
- `schema_version` equals `taffish.index/v1`.
- The top-level `packages` field exists and is an object.
- The top-level `commands` field exists and is an object.
- Every package entry is an object.
- Every package entry has a `versions` object.
- Every package entry has a `latest` value that points to an existing version id.
- Every installable version record contains `version` and `release`.
- Every installable version record contains `command.name`.
- Every installable version record can resolve a source URL.
- Every command entry has a `package` value that points to an existing package.
- Exact artifact names follow `<command>-v<version>-r<release>`.

### Recommended

- A version record should contain `version_id`, equal to `<version>-r<release>`.
- A version record should contain `tag`, equal to `v<version-id>`.
- A version record should contain `kind`, `license`, `repository_url`, and `repository_slug`.
- `source` should contain a canonical GitHub URL and ref.
- Release-tag records should write the indexed Git commit to `source.commit`.
- `container.image_tag` should equal the version id.
- Containerized version records should include `smoke` metadata, image digest, and supported platforms.
- `runtime.pipe` and `runtime.command_mode` should come from the project TOML.
- Command information in the package entry and the version record should be consistent.

### Warnings

- `source` only provides `local_path`, unless this is a development or test index.
- Dependency values use `latest`, `*`, or `null`.
- Package `latest` is not semantically the newest version id.
- The index mixes canonical GitHub URLs and mirror URLs as identities.

## Install Metadata Checks

### Required

- The file is located at `<home>/apps/<package-name>/<version-id>/install.json`.
- `schema_version` equals `taffish.install/v1`.
- `name`, `version_id`, and `artifact_name` are non-empty.
- `command_name` is non-empty or null.
- `command_file`, `launcher_file`, `bin_dir`, `install_root`, and `source_dir` are non-empty.
- `launcher_file` exists.
- `install_root` exists.
- `source_dir` exists.
- The versioned launcher executes `command_file`.
- If a command alias exists, it points to the newest installed version of the current command.

### Recommended

- `installed_at` uses UTC `YYYY-MM-DDTHH:MM:SSZ`.
- `repository_url` remains the canonical GitHub URL.
- `resolved_source_url` records the actual source after source rewrite.
- `source_ref` is consistent with the index record.
- `source_commit` is recorded when possible.
- If `source_commit` is present, `source_commit_actual` equals it and `source_commit_verified` is true.

### Warnings

- `command_file` does not exist while metadata still exists.
- `command_launcher_file` exists but does not contain the current command file.
- `source_commit` is missing, so reproduction depends only on a tag or branch.
- `source_commit` is present but not verified, so the installed source path is not fully auditable.

## Config/Home Checks

### Required

- If `config.toml` exists, its schema is `taffish.config/v1`.
- The config contains no unknown section.
- If `[index].url` exists, it is a non-empty string.
- `[[source.rewrite]].from` and `[[source.rewrite]].to` are non-empty strings.
- If `[[source.rewrite]].enabled` exists, it is a boolean.
- The active home resolves to either user scope or system scope.
- Before install or update, the active home has the required directories or can create them through `taf doctor --init`.

### Recommended

- China mirrors should be implemented through source rewrite, not by changing canonical index records into mirror identities.
- The canonical GitHub organization should be `taffish`.
- The Gitee mirror organization should be `taffish-org`.
- The user-scope command bin should be in `PATH`.

### Warnings

- `TAFFISH_CONFIG` points to a file that overrides source rewrite without documenting why.
- System scope is initialized in a non-root environment.
- The command bin is not in `PATH`.

## Runtime/Container Checks

### Required

- The image in a container tag is non-empty.
- Requested backends are `container`, `docker`, `podman`, `apptainer`, or a `/`-joined combination of them.
- The selected backend exists in available backends.
- If `force-backend` is set, it is `apptainer`, `podman`, or `docker`.
- If Docker, Podman, or Apptainer is missing, the generated shell reports an error and exits.
- When Apptainer auto-pulls from a Docker/OCI source and converts to SIF, missing `mksquashfs` is an error.

### Recommended

- The default backend order should prefer Apptainer, then Podman, then Docker.
- Generated shell should preserve the container debug prelude.
- Container execution should mount home and workdir unless configuration explicitly disables them.
- Unescaped user input should not be concatenated directly into shell commands.
- Image tags should align with taf-app version ids.

### Warnings

- Uses complex `$RUN-ARGS`.
- Disables home/workdir mounts.
- Relies on Apptainer remote auto-pull without pre-caching SIF files.
- Relies on Docker-only behavior in HPC contexts.

## History Checks

### Required

- The history file uses JSON Lines.
- Each line is an independent JSON object.
- Write failure does not change the main command exit code.
- When a wrapper records an `exec` event, it includes `status` and `exit_code`.

### Recommended

- Records `id`, `time`, `command`, `args`, and `cwd`.
- Project commands record project name, version, release, repository, and container image.
- Time uses UTC.

### Warnings

- History lacks `source_commit` or snapshot information, reducing auditability.
- `TAF_HISTORY_MODE=off` is used for formal reproduction without separate provenance records.

## Pre-Release Aggregate Checks

Before releasing a taf-app, at least run:

1. `.taf` file checks.
2. taf-app project checks.
3. Runtime/container checks if the app uses a container.
4. Hub index record checks if the app will enter the Hub.
5. Install metadata checks if installation is being verified.

Before releasing TAFFISH itself or taffish-hub, at least run:

1. Schema version checks.
2. Compatibility policy checks.
3. Source rewrite checks.
4. Old install metadata read checks.
5. Install, run, and uninstall checks for key example apps.

## From Checklist To Automated Conformance Tests

This page can later be split into automated commands:

1. `taf conformance taf <file>`: check a single `.taf` file.
2. `taf conformance project <dir>`: check a taf-app project.
3. `taf conformance index <index.json>`: check a Hub index.
4. `taf conformance install <home>`: check local installation state.

Until that automation exists, this page is the manual reference for migrating taffish-hub and reviewing taf-apps.
