# TAFFISH Localization Contract

This page defines language selection, fallback, external locale-pack layout,
and the boundary between human text and stable machine interfaces.

## Scope

TAFFISH localization is an additive presentation layer. It may translate:

1. `taf`, `taffish`, and `taffish-mcp` human CLI help text.
2. `taf` parser diagnostics.
3. Human-readable project, Hub, package-management, config, doctor, and history
   status and diagnostics produced by `taf`.

Core `taffish` compiler diagnostics may still use the English baseline.
Output owned by a taf-app or an external process is deliberately passed through
instead of localized.

Localization MUST NOT change:

1. Executable, command, subcommand, or option names.
2. Exit codes, TAF syntax, or generated shell.
3. JSON keys, schema versions, enum values, config keys, history fields, or
   Hub index fields.
4. MCP tool/resource/prompt names, schemas, descriptions, or structured
   results.
5. taf-app stdout/stderr or raw stdout/stderr from git, gh, curl, container
   backends, and other external processes.

## Built-In Languages

The canonical built-in language identifiers are:

```text
en
zh
```

Both catalogs are embedded in the delivered binaries and work without an
external locale directory. The human CLI selection defaults to `auto`; `en`
is the complete baseline, the deterministic library/MCP default, and the final
fallback. Common aliases normalize as follows:

```text
en-US, en_US       -> en
zh-CN, zh_CN       -> zh
zh-Hans            -> zh
```

Other identifiers use a conservative BCP 47-style spelling, such as `ja-JP`.

## Language Resolution

The human CLI resolves language in this order:

1. `TAFFISH_LANGUAGE`.
2. The config file named by `TAFFISH_CONFIG`.
3. User config at `$TAFFISH_USER_HOME/config.toml` or its default path.
4. System config at `$TAFFISH_SYSTEM_HOME/config.toml` or its default path.
5. Implicit `auto` selection.

Whenever the selected value is `auto`, including when no config supplies a
language, the CLI consults `LC_ALL`, `LC_MESSAGES`, and `LANG`. An unavailable,
unset, `C`, or `POSIX` locale resolves to `en`. Persist `en` or `zh` when human
output must be deterministic across machines. The `taffish-mcp -h` human CLI
surface follows this resolution. Library calls do not implicitly inherit human
CLI localization; a caller may explicitly establish a language context for a
human renderer. The MCP stdio protocol remains English regardless of human CLI
language selection.

Catalog lookup uses:

```text
exact locale -> base language -> en
```

For example, `ja-JP` falls back through `ja` to `en`.

The CLI resolves its language once at the process entry point. Every human
renderer in that invocation uses the same dynamic language context; it does
not re-read config or locale variables between messages.

## Language Management CLI

Use the config command instead of editing the preference by hand:

```text
taf config language
taf config language --show
taf config language en
taf config language zh
taf config language auto
taf config language <external-locale>
taf config language <language> --system
```

The first two forms are equivalent and read-only. Their output distinguishes
the configured language from the language actually displayed, identifies the
source and config file, and lists built-in and valid external languages.
This distinction is important when `TAFFISH_LANGUAGE` temporarily masks a
saved preference.

The setter writes user scope by default. System scope requires root. It changes
only the top-level `language` assignment and preserves comments, sections,
source profiles, index settings, and unknown future fields. `en`, `zh`, and
`auto` are always accepted; any other value must resolve to an external pack
currently listed by `--show`.

## External Locale Packs

External packs are an optional advanced-user feature. They live under:

```text
$TAFFISH_SYSTEM_HOME/share/locales/<locale>/
$TAFFISH_USER_HOME/share/locales/<locale>/
```

Supported files are:

```text
messages.json
example.txt
help/taf.txt
help/taf/<command>.txt
help/taffish.txt
```

External packs provide independent human-presentation components. Help files
override `taf` and `taffish` help, while `messages.json` overrides registered
semantic runtime messages used by `taf`. A pack may contain either component,
both components, or only selected command/help/message entries. Missing
components and keys continue through the normal fallback chain.

`taffish-mcp -h` embeds built-in English and Chinese; other selected languages
fall back to English. This does not affect the English MCP protocol.

A locale directory is discoverable only when it has a non-empty valid
`messages.json` object or at least one recognized non-empty help file. Empty,
malformed, and example-only directories are ignored. Directory names use the
canonical locale spelling reported by `taf config language`.

`example.txt` is optional display metadata. TAFFISH reads only its first
non-empty UTF-8 line and truncates it to 256 characters. It does not make an
otherwise invalid locale pack selectable.

`messages.json` is a JSON object whose keys are existing TAFFISH semantic
message keys and whose values are translated strings:

```json
{
  "taf.project.check.header": "Proyecto válido: {name}",
  "taf.project.check.field.root": "directorio raíz"
}
```

Named placeholders MUST exactly match the English baseline. A translation
with missing or additional placeholders is ignored for that key only. Help
files are plain UTF-8 text and are subject to the same placeholder check. A
valid sibling key or help file remains active when another entry is missing or
invalid.

For a given locale, a valid user pack shadows the corresponding system pack.
Exact-locale files are checked before base-language files. Discovery is
shallow and deterministically sorted. External files cannot override the
built-in `en` or `zh` catalogs.

## Safety And Failure Policy

Locale packs are data, never executable code. The implementation reads JSON
through `han.json` and help as plain text; it does not evaluate Lisp forms or
use the Lisp reader for locale content.

Missing files, malformed JSON, non-string values, invalid path components,
and placeholder mismatches fail softly. TAFFISH ignores the invalid candidate
and continues through the fallback chain. A damaged optional locale pack MUST
NOT prevent the CLI from starting.

## Human Layout And Diagnostic Summaries

Hub/doctor field rendering uses a shared, language-independent display-width
helper, not per-language spaces or string character counts. It conservatively
supports selected Unicode narrow/wide characters and combining marks attached
to a supported base. Ambiguous widths, shaping scripts, emoji sequences,
controls and unsupported characters are not guessed. This is not a general
Unicode grapheme engine or an exact model of every terminal/font.

Long labels, long values, multiline or uncertain-width text use separate
label/value lines; values are not truncated or automatically wrapped. The
layout budget is fixed, not a terminal-size query. Alignment does not normalize
or rewrite path/identity values and does not affect machine output.

Default Hub diagnostics group repeated issues by type/state and handling policy
within the selected scope, with counts and at most three examples per group.
Examples may be shortened and control characters sanitized for the summary;
`--verbose` and JSON keep full evidence. English and Chinese must preserve the
same counts, classifications, preview/apply distinction and safety advice.

Human progress is stderr-only: stages/counts update in place on an interactive
TTY, while logs use rate-limited lines. Non-TTY streams and `TERM=dumb` must not
receive cursor controls. JSON and MCP calls suppress progress. This changes
presentation, not diagnostic state, exit codes or machine schemas.

## Compatibility

Adding a translation is compatible when semantic keys, placeholders, command
tokens, machine schemas, the default `auto` selection contract, and final
English fallback remain unchanged. Removing or renaming a semantic key or
changing its placeholder set requires a compatibility review and corresponding
conformance-test updates.

## Operation Stage Messages

Slow-command stage keys use the `taf.progress.*` namespace in `messages.json`.
For example, `"taf.progress.download": "Downloading index"` overrides the
index-download label. The formatter supplies the app identity and optional
current-target/total count; translated labels must not add their own counts or
claim success. Missing keys follow the existing sparse-catalog fallback.
See [command status](../../dev/en/taf-core/command-progress.md).
