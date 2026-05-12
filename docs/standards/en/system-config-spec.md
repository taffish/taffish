# TAFFISH Configuration Specification

This page defines the `config.toml` schema, read order, and source rewrite rules.

## Schema

Current config schema:

```toml
schema_version = "taffish.config/v1"
```

The default configuration is equivalent to:

```toml
schema_version = "taffish.config/v1"
profile = "github"
language = "en"

[index]
url = "https://raw.githubusercontent.com/taffish/taffish-index/main/index/index.json"
```

## Supported TOML Subset

Config files use a restricted TOML subset similar to `taffish.toml`:

1. Top-level keys.
2. The `[index]` section.
3. The `[[source.rewrite]]` array-of-table form.
4. Strings and booleans.
5. Whole-line comments and blank lines.

Arbitrary TOML sections are not currently supported. Unknown sections or keys should be errors.

## Top-Level Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | string | Must be `taffish.config/v1`. |
| `profile` | string | Currently built-in values are `github` and `china`. |
| `language` | string | Defaults to `en`; reserved for localization. |

## `[index]`

| Field | Type | Meaning |
| --- | --- | --- |
| `url` | string | Default Hub index URL. |

Index URL resolution priority:

1. URL explicitly passed to the command.
2. Environment variable `TAFFISH_INDEX_URL`.
3. Runtime variable `*taffish-index-default-url*`.
4. `[index].url` in the effective config.
5. Built-in GitHub default index URL.

## `[[source.rewrite]]`

Source rewrite maps canonical source URLs to mirror URLs. A typical use case is cloning app sources from Gitee mirrors for users in mainland China.

Fields:

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `from` | string | none | Canonical URL prefix. |
| `to` | string | none | Rewritten URL prefix. |
| `enabled` | boolean | `true` | Whether this rule is enabled. |

Rules are matched in order. The first enabled rule whose `from` is a prefix of the canonical URL is applied.

Example:

```toml
[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

## Built-In Profiles

The `github` profile uses the GitHub index:

```toml
schema_version = "taffish.config/v1"
profile = "github"
language = "en"

[index]
url = "https://raw.githubusercontent.com/taffish/taffish-index/main/index/index.json"
```

The `china` profile uses the Gitee index and rewrites GitHub sources to Gitee:

```toml
schema_version = "taffish.config/v1"
profile = "china"
language = "en"

[index]
url = "https://gitee.com/taffish-org/taffish-index/raw/main/index/index.json"

[[source.rewrite]]
from = "https://github.com/taffish/"
to = "https://gitee.com/taffish-org/"
enabled = true
```

Note: the canonical GitHub organization is `taffish`, while the Gitee mirror organization is `taffish-org`.

## Config Merge Order

The effective config starts from the default config and is overridden in order:

1. System config.
2. User config, only in user scope.
3. Explicit config pointed to by `TAFFISH_CONFIG`.

Later config files override fields from earlier config files. `source.rewrite` rules are replaced as a whole field, not merged rule by rule.

## Error Policy

In config files:

1. Unknown schema must be an error.
2. Unknown sections must be errors.
3. Unknown keys must be errors.
4. `from` and `to` must be non-empty strings.
5. `enabled` must be a boolean.

This prevents incorrect configuration from being silently ignored and making download sources, mirrors, or index sources unreproducible.

