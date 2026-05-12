# Public API

This directory records APIs that can be called relatively stably by other TAFFISH modules, future collaborators, or maintenance scripts. It is not a formal external SDK commitment, and it does not mean every listed interface is stable for arbitrary third-party use.

## Stability Labels

| Label | Meaning |
| --- | --- |
| Stable | Recommended for current use and should remain compatible in the short term. |
| Semi-stable | Exported or used in multiple places, but may change as the architecture evolves. |
| Reserved | Exported or reserved, but not currently recommended for use. |
| Internal | `%`-prefixed or unexported functions; not an API commitment. |

## Important Rules

1. `%`-prefixed functions are internal implementation by default and should not be used as dependencies in new upper-level code.
2. Package export does not equal full stability. Some exports exist for debugging, structure access, or future extension.
3. APIs with filesystem, git, network, install, or delete side effects must have separate safety notes.
4. API docs should prioritize inputs, outputs, errors, and side effects, not repeat implementation details.

## Documentation Entries

- [taffish-core API](taffish-core-api.md)
- [Emitter API](emitter-api.md)
- [taf-core API](taf-core-api.md)
- [han API](han-api.md)

## API Layers

Current TAFFISH APIs can be grouped into four layers:

| Layer | Recommended callers | Typical entries |
| --- | --- | --- |
| `han` | TAFFISH internal base-library callers | `han.args:bind-args`, `han.json:read-json-file`, `han.path:join-path` |
| `taffish-core` | TAF compiler callers | `taffish.core:taffish-to-shell` |
| emitter | TAFFISH built-in or future extension tag authors | `taffish.core:defemitter`, `taffish.core:emit-block` |
| `taf-core` | `taf-cli`, management tools, automation scripts | `taf.core:project-build`, `taf.core:hub-install`, `taf.core:system-doctor` |

The normal user command-line experience is provided by `taf-cli` and `taffish-cli`. CLI-layer APIs are not the main focus for now.
