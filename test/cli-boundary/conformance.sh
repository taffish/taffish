# Delivered CLI failure boundaries; no network or container operations.
run_cli_boundary_conformance() {
  for boundary_case in startup diagnostics unwritable-stderr broken-stdout interrupt mcp-recovery
  do
    run_case "cli-boundary/$boundary_case" \
      python3 -I "$TAFFISH_TEST_REPO_ROOT/test/cli-boundary/probe.py" "$boundary_case"
  done
}
