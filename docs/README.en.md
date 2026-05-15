# TAFFISH Documentation

This directory records implementation, specification, and ecosystem design knowledge for TAFFISH. It is written for maintainers, contributors, taf-app authors who need deeper contracts, and users who want to understand how the local CLI, Hub index, containers, mirrors, and MCP interface fit together.

Ordinary users can start from the root [README](../README.md). The documents here go deeper than installation and basic command usage.

## Documentation Scope

This directory prioritizes four kinds of content:

1. Code architecture: ASDF systems, packages, modules, and responsibility boundaries between files.
2. Specification drafts: system contracts for the TAF language, project format, Hub index, install metadata, config, and runtime environment.
3. System architecture: GitHub/Gitee organizations, Hub, index, release flow, mirror flow, and ecosystem operation.
4. Development workflow: what to read when changing a module, which invariants to keep, and how to avoid breaking upstream/downstream contracts.

This directory does not try to replace the website or Hub user guide. Paper narratives, tutorials, and application-specific examples can live in dedicated repositories or website documentation when they become stable.

## Entries

- [Developer Manual](dev/README.en.md)
- [TAFFISH Specification Draft](standards/README.en.md)
- [TAFFISH System Architecture](architecture/README.en.md)
- [Release Notes](releases/v0.9.0.md)

Chinese entries:

- [Chinese Developer Manual](dev/README.zh-CN.md)
- [Chinese TAFFISH Specification Draft](standards/README.zh-CN.md)
- [Chinese TAFFISH System Architecture](architecture/README.zh-CN.md)
- [Chinese Release Notes](releases/v0.9.0.zh-CN.md)

## Writing Principles

Every developer document should first answer "why does this code exist", then answer "which APIs does it export". Listing function names alone is usually not enough, because TAFFISH's key complexity comes from contracts between modules rather than individual functions.

Specification documents should first answer "what does TAFFISH promise to the ecosystem", then explain how the current reference implementation satisfies that promise. Specifications may reference implementation, but should not be locked to concrete file layout.

System architecture documents should answer "which repositories, organizations, indexes, mirrors, and release paths make up the TAFFISH ecosystem". They may reference specification and developer docs, but their focus is not code implementation and not individual schema fields.

Recommended order:

1. Role.
2. System position.
3. Upstream and downstream interaction.
4. Core data structures or invariants.
5. Public API.
6. Implementation notes.
7. Modification guide.

## Status

This is a living documentation set. It should evolve with the source code rather than be written only after the project is complete. TAFFISH's core code now has a fairly clear layering; the current docs include Chinese originals and corresponding English versions for the developer manual, specification draft, and system architecture. Future work can add more detailed topics, testing docs, release runbooks, and public user docs.
