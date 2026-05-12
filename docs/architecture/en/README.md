# TAFFISH Architecture Docs

This directory records TAFFISH ecosystem architecture. It is not a user manual and not a source-code developer manual. It explains how TAFFISH operates as a multi-repository, multi-artifact, multi-mirror-source system.

## Current Documents

- [GitHub Organization Architecture](github-organization.md)
- [Automation Pipeline Architecture](automation-pipelines.md)
- [App Release Lifecycle](app-release-lifecycle.md)
- [taffish-hub Architecture](taffish-hub-architecture.md)

## Architecture Layers

TAFFISH can be viewed as five ecosystem layers:

| Layer | Representative objects | Main responsibility |
| --- | --- | --- |
| Core distribution layer | `taffish/taffish` | Distribute `taf`, `taffish`, `taffish-mcp`, install scripts, completions, editor files, and binary releases. |
| App source layer | `taffish/<app>` | Source, tags, releases, Actions, and container images for each taf-app. |
| Index layer | `taffish/taffish-index` | Publish static JSON index files consumed by local `taf` commands. |
| Presentation layer | `taffish.github.io` / `taffish/taffish.github.io` | Web Hub for browsing apps, versions, dependencies, and install commands. |
| Mirror layer | `gitee.com/taffish-org/*` | Read/install/source-rewrite path for users in China. |

Automation pipelines cross these layers: app repositories publish their own GHCR images, `taffish-index` scans the canonical GitHub organization and generates static index files, Web Hub reads the index for display, and Gitee mirror synchronization changes access paths without changing canonical identity.

The app release lifecycle turns these layers into a maintainer workflow: from `taf new`, `taf check`, and `taf publish`, through GHCR, index, Gitee mirror, and user-side installation verification.

The `taffish-hub` architecture explains how the maintainer-side local factory organizes app staging, index, Web Hub, public docs, website, upstream update queue, and archive snapshots.

## Relationship To Standards

Architecture docs describe where things live and how they flow. Exact formats are still defined by standards:

1. Hub index schema: [Hub Index Specification](../../standards/en/hub-index-spec.md).
2. App project format: [TAFFISH Project Specification](../../standards/en/taffish-project-spec.md).
3. Configuration and source rewrite: [TAFFISH Configuration Specification](../../standards/en/system-config-spec.md).
4. Install metadata: [Install Metadata Specification](../../standards/en/install-metadata-spec.md).
5. MCP interface: [TAFFISH MCP Interface Specification](../../standards/en/mcp-interface-spec.md).
