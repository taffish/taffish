# External conformance tests for real taf project workflows.
# This file is sourced by test/run-tests.sh.

_taf_project_case_new_check_compile_from_nested() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-nested
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new external-flow --flow >/dev/null || exit 1
    cd external-flow/src || exit 1
    "$TAF_BIN" check >/dev/null || exit 1
    shell=$("$TAF_BIN" compile) || exit 1
    output=$(printf '%s\n' "$shell" | sh) || exit 1
    assert_eq "<flow>[external-flow: 0.1.0] Hello, World!" "$output" \
      "taf compile from nested project" || exit 1
  )
}

_taf_project_case_build_wrapper_run_compile_help() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-build-wrapper
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new wrapper-flow --flow >/dev/null || exit 1
    cd wrapper-flow || exit 1
    cat > docs/help.md <<'HELP'
# wrapper-flow help

This help text is frozen into the built wrapper.
HELP
    "$TAF_BIN" build >/dev/null || exit 1
    wrapper=target/taf-wrapper-flow-v0.1.0-r1
    assert_executable "$wrapper" || exit 1

    help_output=$("$wrapper" --help) || exit 1
    assert_contains "$help_output" "wrapper-flow help" "built wrapper help" || exit 1

    compile_output=$("$wrapper" --compile) || exit 1
    assert_contains "$compile_output" "<flow>[wrapper-flow: 0.1.0] Hello, World!" \
      "built wrapper compile" || exit 1

    run_output=$("$wrapper") || exit 1
    assert_eq "<flow>[wrapper-flow: 0.1.0] Hello, World!" "$run_output" \
      "built wrapper run" || exit 1
  )
}

_taf_project_case_build_uses_frozen_snapshot() {
  dir=$TAFFISH_TEST_TMP_ROOT/taf-project-frozen
  mkdir -p "$dir"
  (
    cd "$dir" || exit 1
    "$TAF_BIN" new frozen-flow --flow >/dev/null || exit 1
    cd frozen-flow || exit 1
    "$TAF_BIN" build >/dev/null || exit 1
    wrapper=target/taf-frozen-flow-v0.1.0-r1
    assert_executable "$wrapper" || exit 1

    cat > src/main.taf <<'TAF'
<taffish>
echo 'LIVE SOURCE CHANGED'
TAF

    run_output=$("$wrapper") || exit 1
    assert_eq "<flow>[frozen-flow: 0.1.0] Hello, World!" "$run_output" \
      "built wrapper uses frozen snapshot" || exit 1

    live_shell=$("$TAF_BIN" compile) || exit 1
    assert_contains "$live_shell" "LIVE SOURCE CHANGED" "live project compile sees changed source" || exit 1
  )
}

run_taf_project_conformance() {
  run_case "taf-project/new-check-compile-from-nested" _taf_project_case_new_check_compile_from_nested
  run_case "taf-project/build-wrapper-run-compile-help" _taf_project_case_build_wrapper_run_compile_help
  run_case "taf-project/build-uses-frozen-snapshot" _taf_project_case_build_uses_frozen_snapshot
}
