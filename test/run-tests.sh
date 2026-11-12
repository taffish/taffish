#!/bin/sh
set -eu

usage() {
  cat <<'USAGE'
Usage:
  test/run-tests.sh [OPTIONS]

Run external TAFFISH tests against built binaries.

Options:
  --version VERSION       Release version to test. Defaults to taffish.asd.
  --target-dir DIR        Directory containing release binaries. Defaults to target/.
  --taf PATH              Override taf binary path.
  --taffish PATH          Override taffish binary path.
  --taffish-mcp PATH      Override taffish-mcp binary path.
  --filter TEXT           Run only cases whose names contain TEXT.
  --keep-tmp              Preserve the isolated test root after success.
  -h, --help              Show this help.

Failed runs always preserve their test root and per-case logs.
USAGE
}

fail() {
  printf '[test:FAIL] %s\n' "$*" >&2
  exit 1
}

absolute_command_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *)
      command_dir=$(dirname -- "$1")
      command_name=$(basename -- "$1")
      command_dir=$(CDPATH= cd -- "$command_dir" && pwd -P) || return 1
      printf '%s/%s\n' "$command_dir" "$command_name"
      ;;
  esac
}

find_utf8_locale() {
  for candidate in C.UTF-8 C.utf8 en_US.UTF-8 en_US.utf8
  do
    if charmap=$(LC_ALL=$candidate LANG=$candidate locale charmap 2>/dev/null); then
      normalized=$(printf '%s' "$charmap" | tr '[:lower:]' '[:upper:]' | tr -d '-')
      if [ "$normalized" = UTF8 ]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

VERSION=
TARGET_DIR=$REPO_ROOT/target
TAF_BIN=
TAFFISH_BIN=
TAFFISH_MCP_BIN=
TAFFISH_TEST_KEEP_TMP=${TAFFISH_TEST_KEEP_TMP:-0}
TAFFISH_TEST_FILTER=${TAFFISH_TEST_FILTER:-}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      shift
      [ "$#" -gt 0 ] || fail "--version requires an argument"
      VERSION=$1
      ;;
    --target-dir)
      shift
      [ "$#" -gt 0 ] || fail "--target-dir requires an argument"
      TARGET_DIR=$1
      ;;
    --taf)
      shift
      [ "$#" -gt 0 ] || fail "--taf requires an argument"
      TAF_BIN=$1
      ;;
    --taffish)
      shift
      [ "$#" -gt 0 ] || fail "--taffish requires an argument"
      TAFFISH_BIN=$1
      ;;
    --taffish-mcp)
      shift
      [ "$#" -gt 0 ] || fail "--taffish-mcp requires an argument"
      TAFFISH_MCP_BIN=$1
      ;;
    --keep-tmp)
      TAFFISH_TEST_KEEP_TMP=1
      ;;
    --filter)
      shift
      [ "$#" -gt 0 ] || fail "--filter requires an argument"
      TAFFISH_TEST_FILTER=$1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
  shift
done

if [ -z "$VERSION" ]; then
  VERSION=$(sed -n 's/.*:version "\([^"]*\)".*/\1/p' "$REPO_ROOT/taffish.asd" | head -n 1)
fi
[ -n "$VERSION" ] || fail "could not infer version from taffish.asd"
if [ -d "$TARGET_DIR" ]; then
  TARGET_DIR=$(CDPATH='' cd -- "$TARGET_DIR" && pwd -P)
fi

case "$(uname -s)" in
  Darwin) OS=darwin ;;
  Linux) OS=linux ;;
  *) fail "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
  arm64|aarch64) ARCH=arm64 ;;
  x86_64|amd64) ARCH=amd64 ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
esac

[ -n "$TAF_BIN" ] || TAF_BIN=$TARGET_DIR/taf-$OS-$ARCH-$VERSION
[ -n "$TAFFISH_BIN" ] || TAFFISH_BIN=$TARGET_DIR/taffish-$OS-$ARCH-$VERSION
[ -n "$TAFFISH_MCP_BIN" ] || TAFFISH_MCP_BIN=$TARGET_DIR/taffish-mcp-$OS-$ARCH-$VERSION

TAF_BIN=$(absolute_command_path "$TAF_BIN")
TAFFISH_BIN=$(absolute_command_path "$TAFFISH_BIN")
TAFFISH_MCP_BIN=$(absolute_command_path "$TAFFISH_MCP_BIN")
[ -x "$TAF_BIN" ] || fail "taf binary not executable: $TAF_BIN"
[ -x "$TAFFISH_BIN" ] || fail "taffish binary not executable: $TAFFISH_BIN"
[ -x "$TAFFISH_MCP_BIN" ] || fail "taffish-mcp binary not executable: $TAFFISH_MCP_BIN"
command -v git >/dev/null 2>&1 || fail "git is required by external tests"
command -v python3 >/dev/null 2>&1 || fail "python3 is required by external tests"
command -v curl >/dev/null 2>&1 || fail "curl is required by installer external tests"
command -v locale >/dev/null 2>&1 || fail "locale is required by external tests"
TAFFISH_TEST_UTF8_LOCALE=$(find_utf8_locale) || \
  fail "no UTF-8 locale is available for cross-platform Unicode tests"
for fixture in \
  completion/bash/taf \
  completion/zsh/_taf \
  completion/fish/taf.fish
do
  [ -f "$REPO_ROOT/$fixture" ] || fail "required test fixture is missing: $fixture"
done

case "$TAFFISH_TEST_KEEP_TMP" in
  1|true|TRUE|yes|YES) TAFFISH_TEST_KEEP_TMP=1 ;;
  *) TAFFISH_TEST_KEEP_TMP=0 ;;
esac

TAFFISH_TEST_TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/taffish-external-test.XXXXXX")

cleanup_tests() {
  cleanup_status=$?
  trap - 0 1 2 15
  if [ "$TAFFISH_TEST_KEEP_TMP" -eq 1 ] || \
     [ "$cleanup_status" -ne 0 ] || \
     [ "${TAFFISH_TEST_FAILED:-0}" -ne 0 ]; then
    printf '[test] preserved test root: %s\n' "$TAFFISH_TEST_TMP_ROOT" >&2
  else
    rm -rf "$TAFFISH_TEST_TMP_ROOT"
  fi
  exit "$cleanup_status"
}

trap cleanup_tests 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15

TAFFISH_TEST_BIN_DIR=$TAFFISH_TEST_TMP_ROOT/bin
TAFFISH_TEST_LOG_DIR=$TAFFISH_TEST_TMP_ROOT/logs
TAFFISH_TEST_OS_HOME=$TAFFISH_TEST_TMP_ROOT/os-home
TAFFISH_TEST_TMP_DIR=$TAFFISH_TEST_TMP_ROOT/tmp
mkdir -p "$TAFFISH_TEST_BIN_DIR" "$TAFFISH_TEST_LOG_DIR" \
  "$TAFFISH_TEST_OS_HOME" "$TAFFISH_TEST_TMP_DIR"
ln -sf "$TAF_BIN" "$TAFFISH_TEST_BIN_DIR/taf"
ln -sf "$TAFFISH_BIN" "$TAFFISH_TEST_BIN_DIR/taffish"
ln -sf "$TAFFISH_MCP_BIN" "$TAFFISH_TEST_BIN_DIR/taffish-mcp"
mkdir -p "$TAFFISH_TEST_TMP_ROOT/user-home" "$TAFFISH_TEST_TMP_ROOT/system-home"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_CONFIG \
  GIT_CONFIG_SYSTEM GIT_CONFIG_COUNT GIT_TEMPLATE_DIR \
  GIT_CEILING_DIRECTORIES GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL \
  GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
unset TAFFISH_INDEX_URL TAFFISH_SOURCE_DIR TAFFISH_SYSTEM_BIN_DIR \
  TAFFISH_CONTAINER_BACKEND TAFFISH_DOCKER_RUN_ARGS \
  TAFFISH_PODMAN_RUN_ARGS TAFFISH_APPTAINER_RUN_ARGS \
  TAFFISH_ENV TAFFISH_NAME TAFFISH TAF_HISTORY_MODE TAF_HISTORY_FILE
: > "$TAFFISH_TEST_TMP_ROOT/gitconfig"

export TAFFISH_TEST_REPO_ROOT=$REPO_ROOT
export TAFFISH_TEST_TARGET_DIR=$TARGET_DIR
export TAFFISH_TEST_VERSION=$VERSION
export TAFFISH_TEST_TMP_ROOT
export TAFFISH_TEST_LOG_DIR
export TAFFISH_TEST_KEEP_TMP
export TAFFISH_TEST_FILTER
export TAFFISH_TEST_UTF8_LOCALE
export TAF_BIN
export TAFFISH_BIN
export TAFFISH_MCP_BIN
export HOME=$TAFFISH_TEST_OS_HOME
export XDG_CONFIG_HOME=$TAFFISH_TEST_OS_HOME/.config
export XDG_CACHE_HOME=$TAFFISH_TEST_OS_HOME/.cache
export XDG_DATA_HOME=$TAFFISH_TEST_OS_HOME/.local/share
export TMPDIR=$TAFFISH_TEST_TMP_DIR
export TAFFISH_USER_HOME=$TAFFISH_TEST_TMP_ROOT/user-home
export TAFFISH_SYSTEM_HOME=$TAFFISH_TEST_TMP_ROOT/system-home
export TAFFISH_LANGUAGE=en
export TAFFISH_CONFIG=
export LC_ALL=C
export LANG=C
export LANGUAGE=C
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=$TAFFISH_TEST_TMP_ROOT/gitconfig
export GIT_TERMINAL_PROMPT=0
export GH_PROMPT_DISABLED=1
export PATH=$TAFFISH_TEST_BIN_DIR:$PATH

. "$REPO_ROOT/test/lib/harness.sh"
. "$REPO_ROOT/test/taffish/conformance.sh"
. "$REPO_ROOT/test/taf-project/conformance.sh"
. "$REPO_ROOT/test/taf-hub/conformance.sh"
. "$REPO_ROOT/test/taf-system/conformance.sh"
. "$REPO_ROOT/test/i18n/conformance.sh"
. "$REPO_ROOT/test/installer/conformance.sh"
. "$REPO_ROOT/test/cli-boundary/conformance.sh"

harness_log "version: $VERSION"
harness_log "platform: $OS/$ARCH"
harness_log "temporary root: $TAFFISH_TEST_TMP_ROOT"
harness_log "baseline language: $TAFFISH_LANGUAGE"
harness_log "baseline process locale: $LC_ALL"
harness_log "UTF-8 test locale: $TAFFISH_TEST_UTF8_LOCALE"
harness_log "isolated HOME: $HOME"
[ -z "$TAFFISH_TEST_FILTER" ] || harness_log "filter: $TAFFISH_TEST_FILTER"
harness_log "taf: $TAF_BIN"
harness_log "taffish: $TAFFISH_BIN"
harness_log "taffish-mcp: $TAFFISH_MCP_BIN"

run_case "binary/smoke" \
  "$REPO_ROOT/test/binary-smoke.sh" \
  --version "$VERSION" \
  --taf "$TAF_BIN" \
  --taffish "$TAFFISH_BIN" \
  --taffish-mcp "$TAFFISH_MCP_BIN"

run_taffish_conformance
run_taf_project_conformance
run_taf_hub_conformance
run_taf_system_conformance
run_i18n_conformance
run_installer_conformance
run_cli_boundary_conformance

finish_tests
