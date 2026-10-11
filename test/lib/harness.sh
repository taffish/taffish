# Shared shell test harness for TAFFISH external tests.
# This file is sourced by test/run-tests.sh.

TAFFISH_TEST_TOTAL=${TAFFISH_TEST_TOTAL:-0}
TAFFISH_TEST_PASSED=${TAFFISH_TEST_PASSED:-0}
TAFFISH_TEST_FAILED=${TAFFISH_TEST_FAILED:-0}
TAFFISH_TEST_SKIPPED=${TAFFISH_TEST_SKIPPED:-0}
TAFFISH_TEST_LOG_DIR=${TAFFISH_TEST_LOG_DIR:-${TAFFISH_TEST_TMP_ROOT:-/tmp}/logs}

harness_log() {
  printf '[test] %s\n' "$*"
}

harness_fail() {
  printf '%s\n' "$*" >&2
  return 1
}

skip_case() {
  # Called inside run_case's subshell, never counts as a passing test.
  printf '[test:SKIP] %s\n' "$*" >&2
  exit 77
}

assert_eq() {
  expected=$1
  actual=$2
  label=${3:-assert_eq}
  if [ "$expected" = "$actual" ]; then
    return 0
  fi
  printf '%s: expected:\n%s\nactual:\n%s\n' "$label" "$expected" "$actual" >&2
  return 1
}

assert_contains() {
  haystack=$1
  needle=$2
  label=${3:-assert_contains}
  if printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    return 0
  fi
  printf '%s: expected output to contain:\n%s\nactual:\n%s\n' "$label" "$needle" "$haystack" >&2
  return 1
}

assert_not_contains() {
  haystack=$1
  needle=$2
  label=${3:-assert_not_contains}
  if printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    printf '%s: expected output not to contain:\n%s\nactual:\n%s\n' "$label" "$needle" "$haystack" >&2
    return 1
  fi
  return 0
}

assert_executable() {
  path=$1
  [ -x "$path" ] || harness_fail "not executable: $path"
}

capture_command() {
  set +e
  TAFFISH_CAPTURE_OUTPUT=$("$@" 2>&1)
  TAFFISH_CAPTURE_STATUS=$?
  set -e
  return 0
}

assert_capture_success() {
  label=$1
  if [ "$TAFFISH_CAPTURE_STATUS" -eq 0 ]; then
    return 0
  fi
  printf '%s: command failed with exit code %s:\n%s\n' \
    "$label" "$TAFFISH_CAPTURE_STATUS" "$TAFFISH_CAPTURE_OUTPUT" >&2
  return 1
}

assert_capture_failure() {
  label=$1
  if [ "$TAFFISH_CAPTURE_STATUS" -ne 0 ]; then
    return 0
  fi
  printf '%s: command unexpectedly succeeded:\n%s\n' \
    "$label" "$TAFFISH_CAPTURE_OUTPUT" >&2
  return 1
}

_harness_log_name() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9_.-]/_/g'
}

run_case() {
  name=$1
  shift
  if [ -n "${TAFFISH_TEST_FILTER:-}" ]; then
    case "$name" in
      *"$TAFFISH_TEST_FILTER"*) ;;
      *) return 0 ;;
    esac
  fi
  TAFFISH_TEST_TOTAL=$((TAFFISH_TEST_TOTAL + 1))
  mkdir -p "$TAFFISH_TEST_LOG_DIR"
  log_file=$TAFFISH_TEST_LOG_DIR/$(_harness_log_name "$name").log
  set +e
  ( "$@" ) >"$log_file" 2>&1
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    TAFFISH_TEST_PASSED=$((TAFFISH_TEST_PASSED + 1))
    printf '[PASS] %s\n' "$name"
  elif [ "$status" -eq 77 ] && grep '^\[test:SKIP\] ' "$log_file" >/dev/null 2>&1; then
    TAFFISH_TEST_SKIPPED=$((TAFFISH_TEST_SKIPPED + 1))
    printf '[SKIP] %s\n' "$name"
    sed -n 's/^\[test:SKIP\] /!!!!!! /p' "$log_file"
  else
    TAFFISH_TEST_FAILED=$((TAFFISH_TEST_FAILED + 1))
    printf '[FAIL] %s\n' "$name"
    printf '!!!!!! exit code: %s\n' "$status"
    printf '!!!!!! log: %s\n' "$log_file"
    if [ -s "$log_file" ]; then
      sed 's/^/!!!!!! /' "$log_file"
    else
      printf '!!!!!! (no output)\n'
    fi
  fi
}

finish_tests() {
  printf '=================================\n'
  printf 'TOTAL: %s, PASSED: %s, FAILED: %s' \
    "$TAFFISH_TEST_TOTAL" "$TAFFISH_TEST_PASSED" "$TAFFISH_TEST_FAILED"
  if [ "$TAFFISH_TEST_SKIPPED" -gt 0 ]; then
    printf ', SKIPPED: %s' "$TAFFISH_TEST_SKIPPED"
  fi
  printf '\n'
  printf '=================================\n'
  if [ "$TAFFISH_TEST_TOTAL" -eq 0 ]; then
    printf '[test:FAIL] no test cases matched filter: %s\n' \
      "${TAFFISH_TEST_FILTER:-<none>}" >&2
    return 1
  fi
  if [ "$TAFFISH_TEST_PASSED" -eq 0 ] && [ "$TAFFISH_TEST_SKIPPED" -gt 0 ]; then
    printf '[test:FAIL] no selected test case passed; skipped cases are not verification\n' >&2
    return 1
  fi
  [ "$TAFFISH_TEST_FAILED" -eq 0 ]
}
