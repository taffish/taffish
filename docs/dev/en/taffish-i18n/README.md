# taffish-i18n

`taffish-i18n` is the shared human-presentation layer used by `taf-cli`,
`taffish-cli`, and selected human renderers in `taf-core`. Its package is
`taffish.i18n`.

## Responsibility

The module owns:

1. Locale normalization and deterministic language selection.
2. Built-in English/Chinese semantic messages and help selection.
3. Safe external locale-pack discovery/loading through `han.json` and plain text.
4. Read-only configured/displayed/source resolution details.
5. Named-placeholder validation and fallback.

It does not own command parsing, business logic, TAF compilation, Hub/index
metadata, machine schemas, or MCP localization.

## Dependency Position

```text
han
  -> taffish-i18n
       -> taffish-cli / taf-core human renderers / taf-cli

taffish-core / taffish-mcp
  -> language-invariance regression only
```

The module deliberately does not depend on `taf-core`. It reads only the
top-level `language` value from standard config paths so both CLIs can share
language selection without a reverse dependency or ASDF cycle.

## File Responsibilities

| File | Role |
| --- | --- |
| `package.lisp` | Define the `taffish.i18n` API. |
| `locale.lisp` | Normalize locale IDs, read the narrow language preference, and establish dynamic human-language context. |
| `render.lisp` | Validate named placeholders and render templates. |
| `catalog.lisp` | Resolve built-in/external messages and help with fallback. |
| `builtin.lisp` | Register shared CLI messages. |
| `test.lisp` | Exercise normalization, priority, safety, fallback, and external packs. |

Program-specific help and diagnostics register semantic keys next to the
human renderer that owns the wording. This prevents the shared module from
accumulating `taf-core` business concepts.

## Public API

The exported API includes:

1. `normalize-language`, `language-fallback-chain`, `resolve-language`, and
   `resolve-language-details`.
2. `available-languages` for deterministic built-in/user/system discovery.
3. `current-language`, `call-with-resolved-language`, `call-with-language`,
   and `with-language`.
4. `register-message`, `message`, `help-text`, and
   `builtin-message-keys`.

`taf-cli:main` and `taffish-cli:main` establish a resolved language context.
With no configured preference, those human CLI entry points use `auto`, follow
a recognized host locale, and fall back to English. Libraries and MCP calls
remain English unless a caller explicitly establishes a human-language
context; the internal English baseline is therefore intentionally distinct
from the human CLI's default selection mode.

`available-languages` lists built-in `en`/`zh` first and then valid external
packs sorted by canonical ID. User packs shadow system packs. An optional
`example.txt` contributes only its first non-empty line, capped at 256
characters; it never establishes pack validity by itself.

Configuration mutation deliberately remains outside this module.
`taf.core:system-config-language` validates against discovery and performs the
narrow top-level config update.

## Safety And Compatibility

External locale files are optional data. Never replace `han.json`/plain-text
loading with `read`, evaluated Lisp, or implementation-specific APIs.
Built-in `en` and `zh` cannot be overridden externally. Invalid files must
fall back rather than prevent startup.

When changing this module, verify all CLI help option tokens, compiler shell
bytes, doctor/config JSON, and MCP tools/resources/prompts remain invariant.
The normative behavior is documented in the
[localization contract](../../../standards/en/localization.md).
