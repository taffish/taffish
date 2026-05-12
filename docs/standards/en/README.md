# TAFFISH Specification Draft And System Contracts

This directory records TAFFISH specification drafts and implementation-facing system contracts. It is not an externally notarized standard and not a formal standard like ANSI Common Lisp. It is the stable agreement between the current reference implementation and the future ecosystem.

Module docs explain where code lives and how modules interact; specification docs explain which behaviors should remain stable, which formats need compatibility, and which changes require migration paths.

## Current Topics

- [Specification Positioning And Version Policy](specification-policy.md)
- [Compatibility Policy](compatibility-policy.md)
- [Conformance Checklist](conformance-checklist.md)
- [TAF Language Contract](taf-language-contract.md)
- [TAF Language Specification Draft](taf-language-spec.md)
- [Generated Shell Contract](generated-shell-contract.md)
- [TAFFISH Project Specification](taffish-project-spec.md)
- [TAFFISH Home And System Layout Specification](system-home-spec.md)
- [TAFFISH Configuration Specification](system-config-spec.md)
- [TAFFISH Hub Index Specification](hub-index-spec.md)
- [TAFFISH Install Metadata Specification](install-metadata-spec.md)
- [TAFFISH History Specification](history-spec.md)
- [TAFFISH Runtime And Container Specification](runtime-container-spec.md)
- [TAFFISH MCP Interface Specification](mcp-interface-spec.md)

## Why Specification Docs Exist

The current codebase is still small enough to understand by reading source, but as Hub, taf-apps, container backends, mirrors, and automated publishing grow, many questions become ecosystem-compatibility questions rather than "does current code run".

Examples:

1. Should a certain `.taf` syntax remain supported long-term?
2. Must generated shell remain POSIX-compatible?
3. Should container backend mounts be unified?
4. How should Hub index schema changes remain compatible with old versions?

Specification docs carry those questions. Otherwise every change would be judged only by current implementation details and could easily break existing taf-apps.

## Specification Layers

TAFFISH currently uses four governance layers:

| Layer | Name | Current state | Purpose |
| --- | --- | --- | --- |
| 1 | Developer docs | established | Explain code structure, module responsibilities, public APIs. |
| 2 | Specification draft | current focus | Define language, project, Hub, install, config, and runtime contracts. |
| 3 | Conformance tests | future | Verify whether an implementation or taf-app conforms. |
| 4 | Formal standard | not started | Consider when multiple implementations or external governance require it. |

This directory starts as a specification draft rather than a formal standard. Drafts can evolve, but they must not drift casually.

## Reading Convention

Normative strength in this directory:

| Marker | Meaning |
| --- | --- |
| Normative | Uses MUST/SHOULD/MAY-like language to describe long-term compatibility contracts. |
| Current implementation | Describes current Common Lisp reference behavior; it may later be standardized or replaced. |
| Unstable | Known to still be in design; external ecosystem should not depend on details. |

If a paragraph is not explicitly marked but contains schema names, file paths, naming rules, parse order, or error conditions, treat it as normative unless context says otherwise.

## Maturity Map

| Topic | Current maturity | Notes |
| --- | --- | --- |
| TAF basic syntax | Draft v0.1 stable | Line types, `ARGS`/`RUN`, parameter tokens, and block structure are implemented. |
| taf-app project format | Draft v0.1 stable | `taffish.toml`, artifact names, and wrapper structure have a reference implementation. |
| Hub index | Draft v0.1 awaiting ecosystem validation | Consumer exists; producer will be validated by `taffish-hub` migration. |
| install metadata | Draft v0.1 stable | Local install/list/which/uninstall depend on these fields. |
| config/home/history | Draft v0.1 stable | Persistent paths and schemas exist; future work mostly extends fields. |
| runtime/container | Draft v0.1 semi-stable | Backend selection and basic mounts are stable; advanced parameters may evolve. |
| MCP interface | Draft v0.1 stable core | Conservative tools/resources/prompts exist; execution and publish remain out of scope. |
| conformance tests | not established | Use checklist first, then automate. |

## Writing Principles

Specification docs should describe stable contracts, not implementation diaries. They should answer:

1. Which behaviors must remain?
2. Which behaviors are current implementation details?
3. Which behaviors are not stable yet?
4. What migration is needed if a contract changes?

## Maintenance Rules

When changing the following, update this directory:

1. `.taf` syntax, tags, parameter substitution, and compilation behavior.
2. `taffish.toml` fields, project layout, build artifacts, and publishing flow.
3. Hub index, install metadata, config files, and history output.
4. Generated shell, wrapper shell, container backends, and runtime environment variables.
5. GitHub/Gitee source rewrite, index URL, installation paths, and command alias rules.
6. MCP tool names, safety boundaries, structured result shape, resources, and prompts.
