# taffish-mcp

`taffish-mcp` is the MCP stdio server for AI clients. It is an adapter over the existing TAFFISH implementation, not a new business layer. Its job is to expose conservative, structured tools, resources, and prompts so an AI client can inspect TAFFISH state without guessing from unstructured terminal output.

## System Position

`taffish-mcp` loads after `taffish-core`, `taffish-cli`, `taf-core`, and `taf-cli`. This is intentional:

1. `taffish-core` owns language compilation.
2. `taf-core` owns project, Hub, config, history, and install logic.
3. `taffish-mcp` converts safe existing capabilities into MCP JSON-RPC tools/resources/prompts.

It must not become a second implementation of project, Hub, or compiler behavior. If a rule belongs to TAFFISH itself, it should live in `taffish-core` or `taf-core`; MCP should call it and shape the result.

## Human CLI Help And Machine Language Boundary

`taffish-mcp -h`, `taffish-mcp --help`, and `taffish-mcp help` are human CLI
surfaces. They follow the same `taf config language` and `TAFFISH_LANGUAGE`
selection as `taf` and `taffish`, with built-in English and Chinese help.

Starting `taffish-mcp` without a help option enters the stdio server directly.
That server does not establish a human-language context: MCP tool/resource/
prompt names, descriptions, schemas, structured results, and AI-facing help
remain stable English machine interfaces.

## Safety Boundary

The MCP server exposes read-oriented and compile-oriented capabilities. It deliberately does not expose:

1. `taf run`.
2. `taf publish`.
3. Container image build/push.
4. Arbitrary shell execution.

Compile tools may return generated shell code, but they do not execute it. App invocation compile validates arguments and returns shell code, but does not run the taf-app or pull container images.

Smoke and trust metadata are exposed as data for inspection. MCP does not run
smoke commands, pull images, or start containers to verify them.

`taffish_check_environment` is the read-only projection of
`taf.core:system-doctor`. It returns the additive diagnostic schema for homes,
config, index, PATH, completion, Vim/Neovim, the Apptainer SIF cache, and
bounded backend probes. Its input schema intentionally contains no init, fix,
force, or repair operation. It does not edit configuration, change
permissions, start services, pull images, or run containers.

Package maintenance tools are planner-oriented. `taffish_check_outdated`,
`taffish_plan_install_all`, `taffish_plan_upgrade`, and `taffish_plan_prune`
call the same `taf-core` maintenance APIs as the CLI, but always use dry-run
semantics from MCP. They may read the local index and install metadata; they
must not install, upgrade, prune, delete, or run containers.

For compile tools that expose `containerBackend`, the effective backend priority is:

1. explicit MCP tool argument `containerBackend`.
2. `TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker` from the MCP server environment.
3. automatic backend selection.

This only changes generated shell for generic `<container:...>` tags. MCP still does not execute the shell or start containers.

MCP compile tools also inherit local runtime arg variables from the MCP server
process:

1. `TAFFISH_DOCKER_RUN_ARGS`
2. `TAFFISH_PODMAN_RUN_ARGS`
3. `TAFFISH_APPTAINER_RUN_ARGS`

These only affect generated shell. MCP does not run the shell.

## Main Files

| File | Responsibility |
| --- | --- |
| `package.lisp` | Package exports. |
| `protocol.lisp` | MCP JSON-RPC framing, response helpers, JSON conversion, version/help text. |
| `i18n.lisp` | Built-in English/Chinese help for the human CLI entry point only. |
| `compiler.lisp` | Source/file validation, compilation, and summary helpers over `taffish-core`. |
| `app.lisp` | Installed taf-app resolution, inspection, usage summary, and safe app invocation compile. |
| `project.lisp` | Current project inspection, usage summary, check, compile, and safe build helpers. |
| `tools.lisp` | MCP tool registry and tool dispatch. |
| `resources.lisp` | MCP resources for help, tool models, current project files, and maintainer guidance. |
| `prompts.lisp` | MCP prompts that guide AI clients toward safe workflows. |
| `server.lisp` | stdio JSON-RPC server loop. |
| `main.lisp` | CLI entry point for `taffish-mcp`. |

## Tool Design

Tool names use a stable `taffish_` prefix. The names should remain short enough for AI clients to understand, but explicit enough to indicate domain:

1. `taffish_compile_source` and related source/file tools are compiler helpers.
2. `taffish_inspect_app`, `taffish_summarize_app_usage`, and `taffish_compile_app_invocation` are taf-app helpers. Inspection/summary results should surface smoke/trust metadata when available.
3. `taffish_check_project`, `taffish_inspect_project`, and `taffish_compile_project` are current-project helpers. Project inspection/summary results should surface smoke/trust metadata when available.
4. Hub/system helpers provide safe query and dry-run operations.
5. `taffish_check_outdated`, `taffish_plan_install_all`,
   `taffish_plan_upgrade`, and `taffish_plan_prune` are package-maintenance
   planners; MCP should use them before suggesting mutating CLI commands.
6. `taffish_check_environment` reuses the core doctor result and only exposes
   read-only structured diagnostics; it must never acquire init/repair inputs.

Errors should use structured output when practical:

```json
{
  "ok": false,
  "error": {
    "kind": "business-error",
    "message": "human-readable error"
  }
}
```

This is important because MCP clients should not need to parse English text to decide what happened.

## Resources And Prompts

Resources are reference material the AI can read before choosing tools. They should stay compact and actionable. Prompts should encode recommended workflows, not long essays.

Good resources explain:

1. Which tools exist.
2. Which tool is safe for which task.
3. What a current project contains.
4. What should not be done through MCP.

Bad resources duplicate all source code or encourage the AI to bypass TAFFISH commands.

## Modification Guide

When changing `taffish-mcp`, check:

1. Does the new tool duplicate an existing tool?
2. Does it expose execution, publishing, image building, or arbitrary shell behavior?
3. Does it call existing `taffish-core` / `taf-core` logic instead of reimplementing it?
4. Does the returned JSON preserve arrays as arrays and objects as objects?
5. Does the error result contain enough structure for an AI client?
6. Do resources/prompts explain the intended safe workflow without overloading context?
7. If it plans a mutating CLI operation, is the MCP version still dry-run only?
