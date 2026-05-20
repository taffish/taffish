#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  test/binary-smoke.sh [OPTIONS]

Smoke-test built TAFFISH binaries from target/.

Options:
  --version VERSION       Release version to test. Defaults to taffish.asd.
  --target-dir DIR        Directory containing release binaries. Defaults to target/.
  --taf PATH              Override taf binary path.
  --taffish PATH          Override taffish binary path.
  --taffish-mcp PATH      Override taffish-mcp binary path.
  -h, --help              Show this help.

The default binary names are:
  target/taf-<os>-<arch>-<version>
  target/taffish-<os>-<arch>-<version>
  target/taffish-mcp-<os>-<arch>-<version>
EOF
}

fail() {
  printf '[binary-smoke:FAIL] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[binary-smoke] %s\n' "$*"
}

contains() {
  haystack=$1
  needle=$2
  label=$3
  if ! printf '%s' "$haystack" | grep -F -- "$needle" >/dev/null 2>&1; then
    printf '%s\n' "$haystack" >&2
    fail "$label: expected output to contain: $needle"
  fi
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

[ -x "$TAF_BIN" ] || fail "taf binary not executable: $TAF_BIN"
[ -x "$TAFFISH_BIN" ] || fail "taffish binary not executable: $TAFFISH_BIN"
[ -x "$TAFFISH_MCP_BIN" ] || fail "taffish-mcp binary not executable: $TAFFISH_MCP_BIN"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/taffish-binary-smoke.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

log "version: $VERSION"
log "platform: $OS/$ARCH"
log "taf: $TAF_BIN"
log "taffish: $TAFFISH_BIN"
log "taffish-mcp: $TAFFISH_MCP_BIN"

taf_version=$("$TAF_BIN" --version)
taffish_version=$("$TAFFISH_BIN" --version)
mcp_version=$("$TAFFISH_MCP_BIN" --version)

contains "$taf_version" "taf $VERSION" "taf --version"
contains "$taffish_version" "taffish $VERSION" "taffish --version"
contains "$mcp_version" "taffish-mcp $VERSION" "taffish-mcp --version"

taf_help=$("$TAF_BIN" --help)
taf_help_install=$("$TAF_BIN" help install)
taf_install_help=$("$TAF_BIN" install --help)
taf_help_upgrade=$("$TAF_BIN" help upgrade)
taf_help_prune=$("$TAF_BIN" help prune)

contains "$taf_help" "taf help [COMMAND]" "taf --help command help route"
contains "$taf_help" "Project commands:" "taf --help project commands"
contains "$taf_help" "outdated [OPTIONS]" "taf --help hub maintenance commands"
contains "$taf_help_install" "Modes:" "taf help install modes"
contains "$taf_help_install" "taf install --all --tools --yes" "taf help install examples"
contains "$taf_install_help" "Modes:" "taf install --help command help"
contains "$taf_install_help" "--from searches upward for taffish.toml" \
  "taf install --help local project details"
contains "$taf_help_upgrade" "taf upgrade [-h | --help]" "taf help upgrade usage"
contains "$taf_help_upgrade" "no changes" "taf help upgrade no changes detail"
contains "$taf_help_prune" "taf prune [-h | --help]" "taf help prune usage"
contains "$taf_help_prune" "keeps shared container images" \
  "taf help prune container cache detail"

cat > "$TMP_ROOT/minimal.taf" <<'EOF'
ARGS
<(--/-n)name>
  world
RUN
<shell>
echo "hello ::name::"
EOF

minimal_shell=$("$TAFFISH_BIN" "$TMP_ROOT/minimal.taf" --name codex)
contains "$minimal_shell" "hello codex" "taffish compile minimal source"
minimal_output=$(printf '%s\n' "$minimal_shell" | sh)
contains "$minimal_output" "hello codex" "compiled minimal shell execution"

cat > "$TMP_ROOT/container-args.taf" <<'EOF'
<docker:alpine:latest$@[all: --pull=never][docker: --gpus all]>
echo "container args"
EOF

container_shell=$(
  TAFFISH_DOCKER_RUN_ARGS="--env TAFFISH_BINARY_SMOKE=1" \
    "$TAFFISH_BIN" "$TMP_ROOT/container-args.taf"
)
contains "$container_shell" "--pull=never" "structured container args"
contains "$container_shell" "--gpus all" "docker-specific container args"
contains "$container_shell" "--env TAFFISH_BINARY_SMOKE=1" "environment container args"

PROJECT_ROOT=$TMP_ROOT/project
mkdir -p "$PROJECT_ROOT"
(
  cd "$PROJECT_ROOT"
  "$TAF_BIN" new binary-smoke --flow >/dev/null
  cd binary-smoke
  "$TAF_BIN" check >/dev/null
  project_shell=$("$TAF_BIN" compile)
  contains "$project_shell" "<flow>[binary-smoke: 0.1.0] Hello, World!" \
    "taf compile generated project"
  project_output=$(printf '%s\n' "$project_shell" | sh)
  contains "$project_output" "<flow>[binary-smoke: 0.1.0] Hello, World!" \
    "compiled project shell execution"
)

mcp_output=$(
  printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"binary-smoke","version":"0"}}}' \
    '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
    '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"taffish_get_version","arguments":{}}}' \
  | "$TAFFISH_MCP_BIN" 2>&1
)
contains "$mcp_output" '"taffish_get_version"' "taffish-mcp tools/list"
contains "$mcp_output" "taffish-mcp $VERSION" "taffish-mcp get_version"

log "all binary smoke checks passed"
