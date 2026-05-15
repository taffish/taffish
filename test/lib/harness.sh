# Shared shell test harness for TAFFISH external tests.
# This file is sourced by test/run-tests.sh.

TAFFISH_TEST_TOTAL=${TAFFISH_TEST_TOTAL:-0}
TAFFISH_TEST_PASSED=${TAFFISH_TEST_PASSED:-0}
TAFFISH_TEST_FAILED=${TAFFISH_TEST_FAILED:-0}

harness_log() {
  printf '[test] %s\n' "$*"
}

harness_fail() {
  printf '%s\n' "$*" >&2
  return 1
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

run_case() {
  name=$1
  shift
  TAFFISH_TEST_TOTAL=$((TAFFISH_TEST_TOTAL + 1))
  set +e
  output=$("$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -eq 0 ]; then
    TAFFISH_TEST_PASSED=$((TAFFISH_TEST_PASSED + 1))
    printf '[PASS] %s\n' "$name"
  else
    TAFFISH_TEST_FAILED=$((TAFFISH_TEST_FAILED + 1))
    printf '[FAIL] %s\n' "$name"
    printf '%s\n' "$output" | sed 's/^/!!!!!! /'
  fi
}

finish_tests() {
  printf '=================================\n'
  printf 'TOTAL: %s, PASSED: %s, FAILED: %s\n' \
    "$TAFFISH_TEST_TOTAL" "$TAFFISH_TEST_PASSED" "$TAFFISH_TEST_FAILED"
  printf '=================================\n'
  [ "$TAFFISH_TEST_FAILED" -eq 0 ]
}
