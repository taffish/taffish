# hub/update, info, search

These files handle Hub index acquisition, loading, target resolution, information display, and search.

## Role

The Hub index is the directory of the TAFFISH ecosystem. `hub/update` stores a remote or local index in TAFFISH home, `hub/info` resolves package/version records from queries, and `hub/search` searches packages in the index.

## hub/update

Responsibilities of `hub-update`:

1. Resolve scope and home.
2. Resolve index URL.
3. Read index from a local file, `file://`, or HTTP(S) URL.
4. Lightly validate the index string.
5. Write `index/current.json`.
6. Write `index/snapshots/index-<timestamp>.json`.

Index URL priority:

1. Explicit `index-url`.
2. Environment variable `TAFFISH_INDEX_URL`.
3. Runtime variable `*taffish-index-default-url*`.
4. `index-url` in system config.
5. `%default-index-url`.

Download uses `curl` with fail, retry, timeout, and related options.

## Index File Location

Under a TAFFISH home:

```text
index/current.json
index/snapshots/index-<timestamp>.json
```

`current.json` is the default file read by Hub query commands. Snapshots preserve index history.

## Index Schema

`hub/info` strictly requires:

```text
schema_version = "taffish.index/v1"
```

and requires the index to be a JSON object containing object fields `packages` and `commands`.

## hub/info Target Resolution

`%hub-resolve-info-target` supports three query types:

| Query type | Resolution |
| --- | --- |
| package name | Direct match in `packages`. |
| command name | Match in `commands`, then return to package. |
| artifact name | Scan package versions and match artifact name. |

version-id is normalized first, allowing an input with leading `v`. If artifact query itself already contains a version, passing a conflicting version-id is not allowed.

## Version Ordering

Hub reuses publish's version/release parsing and comparison logic. When `v<version>-r<release>` can be parsed, versions are sorted by version number and release; otherwise string comparison is used.

## hub/search

Search:

1. Splits query by whitespace into terms.
2. Collects searchable fields from package, command, kind, version, repo, container image, and related data.
3. Requires every term to hit some field.
4. Sorts by score.
5. Supports limit and JSON output.

Scoring roughly prefers:

1. package name.
2. command name.
3. kind.
4. version.
5. repository.
6. container image.

## Modification Guide

When changing Hub index/query layer, check:

1. Whether index schema changes.
2. Whether `hub-install` can still use `hub-info` resolution results.
3. Whether package, command, and artifact queries all remain usable.
4. Whether GitHub/Gitee index URLs remain managed by the config layer.
5. Whether JSON output remains suitable for script consumption.

