# TAFFISH Developer Manual

This manual explains how TAFFISH itself is implemented. It is not a tutorial for writing taf-apps; it is a maintainer guide for the TAFFISH system.

## Recommended Reading Order

1. [Overall Architecture](en/00-overview.md)
2. [ASDF System And Module Map](en/01-asdf-system-map.md)
3. [Module Documentation Template](en/02-module-doc-template.md)
4. [Development Workflow And Maintenance Rules](en/03-development-workflow.md)
5. [0.8.0 Open-Source Preparation Checklist](en/04-open-source-0.8.0-checklist.md)
6. [Build From Source](en/build-from-source.md)
7. [han Base Library](en/han/README.md)
8. [taffish-core](en/taffish-core/README.md)
9. [taf-core](en/taf-core/README.md)
10. [taffish-cli](en/taffish-cli/README.md)
11. [taf-cli](en/taf-cli/README.md)
12. [taffish-mcp](en/taffish-mcp/README.md)
13. [Public API](en/api/README.md)

Related docs: [TAFFISH Specification Draft](../standards/README.en.md) records language, project, Hub, install, config, and runtime contracts. The developer manual may reference those specifications, but it does not treat them as source-code implementation chapters.

## Manual Boundary

This manual only covers TAFFISH development content in the current repository. The TAFFISH specification draft and ecosystem-level topics, such as taffish-hub, GitHub/Gitee mirrors, taf-app publishing and CI, and long-term Hub index governance, belong to higher-level system architecture. This manual explains interfaces and boundaries where needed, but does not mix specification or Hub ecosystem docs into the source-code developer manual.

## Current Code Layers

TAFFISH can currently be understood as six layers:

| Layer | Directory or system | Main responsibility |
| --- | --- | --- |
| Base library | `vendor/han` | Common capabilities such as platform adaptation, paths, JSON, argument specification, and binding. |
| TAF language core | `taffish-core` | Compile `.taf` source code from text into runnable shell scripts. |
| TAF compiler CLI | `taffish-cli` | Provide the CLI entry point for the TAF compiler. |
| Project and Hub tooling | `taf-core` | Support project, Hub, system config, history, and diagnostic features behind the `taf` command. |
| taf command CLI | `taf-cli` | Provide the user-facing `taf` CLI entry point. |
| AI protocol layer | `taffish-mcp` | Expose conservative tools/resources/prompts for MCP-compatible AI clients without adding new business logic. |

## Maintenance Rules

When adding or changing modules, update the corresponding docs. The minimum update is to state whether responsibilities changed, whether public APIs changed, and whether upstream/downstream contracts changed.

If the change only fixes an internal implementation bug, add a short note in the corresponding module doc's "Modification Guide" or "Common Risks" section when it helps future maintainers. TAFFISH docs are not meant to accumulate volume; they are meant to make the parts that future maintainers are most likely to misunderstand explicit.
