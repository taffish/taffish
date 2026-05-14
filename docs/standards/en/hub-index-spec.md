# TAFFISH Hub Index Specification

This page defines the consumer-side specification for `taffish.index/v1`. The index production flow may be implemented by taffish-hub or by other tools, but the output must satisfy this contract.

## Specification Status

| Scope | Status | Notes |
| --- | --- | --- |
| `schema_version`, `packages`, `commands` | Draft v0.1 stable | Consumer commands already depend on these fields. |
| Package entry and version record | Draft v0.1 awaiting ecosystem validation | Field structure is defined, but producer behavior needs validation during taffish-hub migration. |
| dependencies | Draft v0.1 semi-stable | The installer supports recursive installation and cycle detection, but complex ecosystems need more validation. |
| Multi-source mirrors | Current implementation | Implemented through config source rewrite, not directly through index schema. |

## File Format

A Hub index is a JSON object whose top level must contain:

```json
{
  "schema_version": "taffish.index/v1",
  "packages": {},
  "commands": {}
}
```

`taf update` performs only lightweight checks on downloaded content, while `taf info/search/list/install` parse JSON and check the schema.

## Top-Level Fields

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `schema_version` | string | yes | Must be `taffish.index/v1`. |
| `packages` | object | yes | Mapping from package name to package entry. |
| `commands` | object | yes | Mapping from command name to command entry. |

Extra top-level fields may be added, but consumers must not depend on unspecified fields.

## Package Entry

Keys in `packages` are package names. Values should be objects.

Core fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Display package name; may match the key. |
| `latest` | string | Default version id. |
| `repository_url` | string | Canonical repository URL. |
| `command` | object | Default command information for the package. |
| `versions` | object | Mapping from version id to version record. |

`latest` should point to an existing key in `versions`.

## Command Entry

`commands` is used to resolve a command name back to its package.

Typical structure:

```json
{
  "taf-demo": {
    "package": "demo",
    "version": "0.1.0-r1"
  }
}
```

Fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `package` | string | Points to a package key in `packages`. |
| `version` | string | Default version id; if omitted, package `latest` is used. |

## Version ID

The current version id form is:

```text
<version>-r<release>
```

When users enter a version id, a leading `v` is normalized away. Therefore `v0.1.0-r1` and `0.1.0-r1` resolve to the same version id.

Version id ordering uses `v<version>-r<release>` semantics first:

1. If version can be compared as dot-separated numbers, compare numerically.
2. If versions are equal, compare release as a positive integer.
3. If parsing fails, fall back to string comparison.

## Version Record

A version record represents a concrete release.

Core fields:

| Field | Type | Required | Meaning |
| --- | --- | --- | --- |
| `name` | string | recommended | Package name. |
| `kind` | string | recommended | `tool` or `flow`. |
| `version` | string | required for install | Package version. |
| `release` | integer/string | required for install | Release number. |
| `version_id` | string | recommended | `<version>-r<release>`. |
| `tag` | string | optional | Git tag; defaults to `v<version-id>`. |
| `license` | string | recommended | License id. |
| `repository_url` | string | recommended | Canonical repository URL. |
| `repository_slug` | string | optional | For example `taffish/demo`. |
| `meta` | object | optional | Discovery metadata copied from `[meta]` in `taffish.toml`. |
| `upstream` | object | optional | Upstream provenance metadata copied from `[upstream]` in `taffish.toml`. |
| `command` | object | required for install | Command information. |
| `runtime` | object | recommended | Runtime information. |
| `paths` | object | recommended | Project-internal path information. |
| `container` | object | optional | Container information. |
| `smoke` | object | optional | Declared smoke checks and index-side smoke result. |
| `source` | object | recommended for install | Source clone/copy information. |
| `dependencies` | object | optional | Dependent apps. |

## `meta`

`meta` records discovery metadata from `[meta]` in `taffish.toml`. It is meant
for search, categorization, and display. Consumers should treat it as optional.

Recommended fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `domain` | string | Broad domain, such as `bioinformatics`. |
| `category` | string | More specific area, such as `molecular-docking`. |
| `summary` | string | One-sentence description. |
| `keywords` | array | Search keywords and aliases. |

## `upstream`

`upstream` records the original software, method, database, or workflow wrapped
by the taf-app. It is distinct from the TAFFISH app repository.

Recommended fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Upstream software/method/resource name. |
| `type` | string | Optional source type, such as `official`, `github`, `gitlab`, `archive`, `docker`, `apt`, `conda`, or `other`. |
| `version` | string | Upstream version wrapped by this taf-app release. |
| `url` | string | Upstream homepage, repository, or documentation URL. |
| `homepage` | string | Upstream homepage when different from `url`. |
| `repository` | string | Upstream source repository URL or slug when known. |
| `release_url` | string | Upstream release page when known. |
| `docker_image` | string | Existing upstream Docker image when known; this is not the TAFFISH-built image. |
| `license` | string | Upstream open-source license, preferably an SPDX identifier when known. |
| `citation` | string | Short citation text when available. |
| `doi` | string | DOI for the upstream method/software paper when available. |
| `pmid` | string | PubMed ID for the upstream method/software paper when available. |

Index generators should accept `[upstream].repo` from `taffish.toml` as a
compatibility alias and normalize it to `upstream.repository` in generated
index records.

`upstream.license` describes the upstream software/resource license. The
top-level package `license` field describes the TAFFISH wrapper license.
For scholarly bioinformatics tools, `citation`, `doi`, and `pmid` preserve
verified academic attribution metadata.

Index-side metadata overrides may supplement `license`, `citation`, `doi`, and
`pmid` on records that already have upstream data. They should not create a new
upstream object for a record that did not declare upstream metadata.

## `command`

The `command` object should contain at least:

| Field | Type | Meaning |
| --- | --- | --- |
| `name` | string | Required for install; must be a taf command name. |

Artifact names are computed by consumers from command, version, and release:

```text
<command.name>-v<version>-r<release>
```

## `runtime`

Recommended fields:

| Field | Type |
| --- | --- |
| `pipe` | boolean |
| `command_mode` | boolean |

These fields should come from `[runtime]` in `taffish.toml`.

## `paths`

Recommended fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `main` | string | Main TAF file path. |
| `help` | string | Help file path. |
| `dockerfile` | string/null | Dockerfile path. |

## `container`

Recommended fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `image` | string | Container image. |
| `image_tag` | string | Image tag, usually equal to the version id. |
| `dockerfile` | string/null | Dockerfile path. |
| `digest` | string | Optional immutable OCI digest, for example `sha256:...`. |
| `platforms` | array | Optional supported platform list, for example `["linux/amd64"]`. |

## `smoke`

`smoke` records declarative checks from `[smoke]` in `taffish.toml`, and may
also record index-side execution results.

Recommended fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `backend` | string | Preferred backend used for smoke, such as `docker`. |
| `timeout` | integer | Per-command timeout in seconds. |
| `exist` | array | Executable names expected in container `PATH`. |
| `test` | array | Shell commands expected to exit with status `0`. |
| `status` | string | Optional producer result, such as `passed`, `failed`, or `skipped`. |
| `checked_at` | string | Optional timestamp for producer-side smoke execution. |

## `source`

Source URL resolution priority during install:

1. `source.local_path`
2. `source.clone_url`
3. `source.repository_url`
4. Top-level `repository_url` in the version record

Source ref resolution priority:

1. `source.ref`
2. `tag`
3. `v<version-id>`

Optional fields:

| Field | Type | Meaning |
| --- | --- | --- |
| `local_path` | string | Local source directory, mainly for development and tests. |
| `clone_url` | string | Git clone URL. |
| `repository_url` | string | Canonical repository URL. |
| `html_url` | string | Display URL. |
| `ref` | string | Branch/tag used for clone. |
| `commit` | string | Source commit record. |

The source URL is passed through config source rewrite before install. When
`commit` is present, `taf install` verifies that the resolved source has this
Git `HEAD` commit and a clean worktree before building the installed command.
Official public index producers should record `source.commit` for release-tag
records.

## Trust Metadata

For the official public TAFFISH index, a containerized version record should be
accepted only after the index producer can record:

1. source identity: repository, ref/tag, and commit.
2. container identity: image tag, immutable digest, and supported platforms.
3. smoke result: declared checks and producer-side pass status.

Consumers should treat these fields as audit/trust metadata. They are not a
replacement for scientific validation of the upstream tool, but they make the
delivery path traceable from index record to source commit and container image.

## `dependencies`

`dependencies` is an object whose keys are query targets and whose values select versions.

Values may be:

1. `null`
2. `"latest"`
3. `"*"`
4. A version id string
5. An array of version id strings

`null`, `latest`, and `*` all mean the default version.

Example:

```json
{
  "dependencies": {
    "taf-fastqc": "0.12.1-r1",
    "taf-samtools": ["1.20-r1", "latest"]
  }
}
```

The installer must detect dependency cycles.

## Query Resolution

`taf info/install` resolves query targets in this order:

1. Package name.
2. Command name.
3. Exact artifact name.

Exact artifact names have the form:

```text
<command.name>-v<version>-r<release>
```

If the user queries an exact artifact name and also passes an inconsistent version id, that is an error.

## Index Update

`taf update` supports:

1. Local file paths.
2. `file://` URLs.
3. `http://` or `https://` URLs.

After update, TAFFISH should write:

```text
<home>/index/current.json
<home>/index/snapshots/index-<timestamp>.json
```

Index download failures should normally mention network or proxy issues and allow users to choose a source through `taf update --url <INDEX-URL>` or `TAFFISH_INDEX_URL`.
