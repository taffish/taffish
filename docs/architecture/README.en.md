# TAFFISH System Architecture

This directory records TAFFISH beyond the source code: GitHub/Gitee organization layout, repository layers, Hub, index, release flow, mirror flow, and the user-facing runtime path.

It relates to `dev/` and `standards/` as follows:

| Directory | Focus | Typical question |
| --- | --- | --- |
| `dev/` | Current implementation | How does `project-publish` call git/gh? |
| `standards/` | Logical contracts | Which fields must `taffish.index/v1` contain? |
| `architecture/` | Ecosystem topology and operating flows | Which repositories should exist in the GitHub organization? Where do users install apps from? |

Current English entry:

- [English architecture docs](en/README.md)

## Current Focus

The first phase records the GitHub organization architecture, automation pipelines, app release lifecycle, and `taffish-hub` architecture. These are the top-level designs shared by `taf new`, `taf publish`, `taffish-index`, GitHub Actions, GHCR, Gitee mirrors, and user installation paths.

Future topics can include:

1. China mirror synchronization architecture.
2. Website and documentation-site architecture.
3. Maintainer recovery runbook.
