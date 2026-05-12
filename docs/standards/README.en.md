# TAFFISH Specification Draft

This directory records TAFFISH logical contracts and specification drafts. It relates to `dev/` as follows:

| Directory | Audience | Question answered |
| --- | --- | --- |
| `dev/` | TAFFISH implementation maintainers | Where is the code, how do modules interact, how are APIs implemented? |
| `standards/` | TAFFISH ecosystem and compatibility maintainers | What should the language, project format, Hub, install metadata, config, and runtime promise? |

Current English entry:

- [English specification draft](en/README.md)
- [Conformance checklist](en/conformance-checklist.md)

## Positioning

This is not an externally notarized standard and not a formal standard like ANSI Common Lisp. At the current stage the better name is:

```text
TAFFISH Specification Draft v0.1
```

It can evolve as the reference implementation and `taffish-hub` migration evolve, but it should have explicit versions, compatibility policy, and migration notes.

## Boundary With Developer Docs

Specification documents may reference the current Common Lisp reference implementation, but they should not require a specific function or file layout to be valid.

Examples:

1. Which fields exist in `taffish.toml` is a specification issue.
2. How `project-check` parses those fields is a dev-doc issue.
3. Hub index schema is a specification issue.
4. How `hub-info` queries the index is a dev-doc issue.
5. Container backend selection is a specification issue.
6. How `container.lisp` emits shell is a dev-doc issue.

This separation lets TAFFISH later move toward multiple implementations, conformance testing, and ecosystem governance instead of being locked to the current source layout.

## Immediate Use

This specification draft directly supports `taffish-hub` migration. During migration, check first:

1. Generated index conforms to `taffish.index/v1`.
2. Each taf-app project conforms to `taffish.toml` and directory specifications.
3. Install results generate correct `install.json` and launcher files.
4. China mirror config changes distribution source only through source rewrite and does not change canonical GitHub identity.
