# Security Policy

TAFFISH is a local workflow/compiler and package-management system for bioinformatics tools. Security reports are welcome, especially issues related to command generation, shell escaping, container execution, installer behavior, Hub index metadata, source verification, and release artifact integrity.

## Supported Versions

The current public development line is `0.x`. Security fixes are expected to target the latest released version first.

## Reporting A Vulnerability

Please report suspected vulnerabilities privately before opening a public issue.

Preferred contact:

```text
security@taffish.com
```

If that address is unavailable, use a private GitHub security advisory if enabled for the repository, or contact the maintainer through the official TAFFISH organization channels.

Please include:

- affected TAFFISH version;
- operating system and architecture;
- exact command or taf-app metadata involved;
- minimal reproduction steps;
- expected impact;
- whether the issue affects `taffish`, `taf`, `taffish-mcp`, installers, or Hub/index metadata.

## Scope

In scope:

- command injection or unsafe shell generation;
- unsafe path handling or file overwrite behavior;
- installer download or permission problems;
- source commit verification bypass;
- package index trust metadata issues;
- MCP tools that unexpectedly execute workflows or modify state;
- container backend invocation mistakes that change the intended command boundary.

Out of scope unless they expose a TAFFISH-specific bug:

- vulnerabilities in upstream bioinformatics tools;
- vulnerabilities in Docker, Podman, Apptainer, Git, GitHub, Gitee, or operating systems;
- network blocking or mirror availability problems;
- intentionally running untrusted taf-apps or containers.

## Current Release Integrity Model

TAFFISH 0.8.0 publishes manually built binary payloads under `target/` with `SHA256SUMS`, `SHA256SUMS.asc`, and `TAFFISH-RELEASE-KEY.asc` files. This provides signed checksum verification, but it is not yet a reproducible-build or GitHub Actions provenance guarantee.

TAFFISH Hub package trust is expected to rely on index metadata such as source commit, container digest/platforms, and smoke-test results.
