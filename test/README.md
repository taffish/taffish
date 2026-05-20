# TAFFISH External Tests

This directory contains shell-level tests for built TAFFISH binaries. These
tests complement the Common Lisp unit tests by exercising the delivered
`taf`, `taffish`, and `taffish-mcp` commands as external programs.

Run the full external suite for the current platform:

```sh
test/run-tests.sh --version 0.10.0
```

For local unsuffixed builds:

```sh
test/run-tests.sh \
  --taf ./target/taf \
  --taffish ./target/taffish \
  --taffish-mcp ./target/taffish-mcp
```

Current suites:

- `binary-smoke.sh`: minimal binary startup and MCP smoke checks.
- `taffish/conformance.sh`: real `taffish` source/stdin compilation behavior,
  argument binding, error paths, and container runtime-argument compilation.
  It includes generic `<container:...>` backend-selection checks for structured
  `$@[...]` arguments across Docker, Podman, and Apptainer using local command
  shims for deterministic backend discovery.
- `taf-project/conformance.sh`: real `taf new/check/compile/build` project
  workflows and built-wrapper behavior.
- `taf-hub/conformance.sh`: real local Hub package-maintenance workflows,
  including `install --all`, `outdated`, `upgrade --prune-old`, and `prune`
  against a temporary local index and local source projects. It also checks
  that default text output hides unchanged/current apps while JSON output keeps
  structured detail.

The default suite does not pull images or run containers. Container tests
compile TAF and inspect generated shell contracts so they stay fast and
portable.
