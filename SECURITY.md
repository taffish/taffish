# Security Policy

TAFFISH is a shell-native reproducible execution and delivery layer for
bioinformatics command-line tools and lightweight workflows. Security reports
are welcome, especially issues related to command generation, shell escaping,
container execution, installer behavior, Hub index metadata, source
verification, and release artifact integrity.

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

Current tagged TAFFISH releases publish manually built binary payloads under
`target/` with `SHA256SUMS`, `SHA256SUMS.asc`, and
`TAFFISH-RELEASE-KEY.asc`. This provides signed checksum verification, but it
is not a reproducible-build or GitHub Actions provenance guarantee.

The current raw installers require every selected official GitHub/Gitee binary
to match `SHA256SUMS` before replacing a command. In default `auto` mode they
also verify the signed manifest against the fixed TAFFISH release-key
fingerprint when `gpg` and `gpgv` are available; strict `sha256` and `gpg`
modes are available. Custom sources without verification material remain
explicitly marked unverified in compatible `auto` mode.

Payload verification does not independently authenticate an installer script
obtained through `curl | sh`. High-security deployments should obtain and
inspect a fixed-tag installer through an independently trusted channel before
running it. Installation itself uses a per-home lock, candidate binary smoke
tests, transactional replacement, rollback, and a non-secret install receipt.
Shared writable Apptainer cache permissions are never enabled silently.

TAFFISH Hub package trust uses index metadata such as source commit, container
digest/platforms, and smoke-test results where those fields are available.
