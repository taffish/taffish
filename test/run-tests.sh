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
  -h, --help              Show this help.
USAGE
}

fail() {
  printf '[test:FAIL] %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

VERSION=
TARGET_DIR=$REPO_ROOT/target
TAF_BIN=
TAFFISH_BIN=
TAFFISH_MCP_BIN=

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

TAFFISH_TEST_TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/taffish-external-test.XXXXXX")
trap 'rm -rf "$TAFFISH_TEST_TMP_ROOT"' EXIT HUP INT TERM

TAFFISH_TEST_BIN_DIR=$TAFFISH_TEST_TMP_ROOT/bin
mkdir -p "$TAFFISH_TEST_BIN_DIR"
ln -sf "$TAF_BIN" "$TAFFISH_TEST_BIN_DIR/taf"
ln -sf "$TAFFISH_BIN" "$TAFFISH_TEST_BIN_DIR/taffish"
ln -sf "$TAFFISH_MCP_BIN" "$TAFFISH_TEST_BIN_DIR/taffish-mcp"
mkdir -p "$TAFFISH_TEST_TMP_ROOT/user-home" "$TAFFISH_TEST_TMP_ROOT/system-home"

export TAFFISH_TEST_REPO_ROOT=$REPO_ROOT
export TAFFISH_TEST_VERSION=$VERSION
export TAFFISH_TEST_TMP_ROOT
export TAF_BIN
export TAFFISH_BIN
export TAFFISH_MCP_BIN
export TAFFISH_USER_HOME=$TAFFISH_TEST_TMP_ROOT/user-home
export TAFFISH_SYSTEM_HOME=$TAFFISH_TEST_TMP_ROOT/system-home
export PATH=$TAFFISH_TEST_BIN_DIR:$PATH

. "$REPO_ROOT/test/lib/harness.sh"
. "$REPO_ROOT/test/taffish/conformance.sh"
. "$REPO_ROOT/test/taf-project/conformance.sh"

harness_log "version: $VERSION"
harness_log "platform: $OS/$ARCH"
harness_log "temporary root: $TAFFISH_TEST_TMP_ROOT"
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

finish_tests
