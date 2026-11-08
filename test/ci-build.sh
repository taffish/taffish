#!/bin/sh
set -eu

# SBCL-only development builds. Official target/ payloads and signatures are
# deliberately not used or updated by this entry point.
fail() {
  printf '[ci-build:FAIL] %s\n' "$*" >&2
  exit 1
}

[ "$#" -eq 1 ] || fail 'usage: sh test/ci-build.sh /absolute/empty/output-directory'
command -v sbcl >/dev/null 2>&1 || fail 'sbcl is required'
SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd -P)

case "$1" in
  /*) ;;
  *) fail 'output directory must be absolute' ;;
esac
if [ -d "$1" ]; then
  BUILD_DIR=$(CDPATH='' cd -- "$1" && pwd -P)
else
  # Require an existing parent, so validation never creates a source directory.
  BUILD_PARENT=$(CDPATH='' cd -- "$(dirname -- "$1")" && pwd -P) || \
    fail 'output parent directory must already exist'
  BUILD_NAME=$(basename -- "$1")
  case "$BUILD_NAME" in ''|.|..) fail 'invalid output directory name' ;; esac
  BUILD_DIR=$BUILD_PARENT/$BUILD_NAME
fi
case "$BUILD_DIR" in
  "$REPO_ROOT"|"$REPO_ROOT"/*) fail 'output must be outside the source tree' ;;
esac
if [ -e "$BUILD_DIR" ]; then
  [ -d "$BUILD_DIR" ] || fail 'output path is not a directory'
  [ -z "$(find "$BUILD_DIR" -mindepth 1 -maxdepth 1 -print)" ] || \
    fail 'output directory must be empty'
else
  mkdir -- "$BUILD_DIR"
fi

mkdir -- "$BUILD_DIR/cache" "$BUILD_DIR/logs"
sbcl --version
printf '[ci-build] source: %s\n[ci-build] output: %s\n' "$REPO_ROOT" "$BUILD_DIR"
for name in taf taffish taffish-mcp; do
  printf '[ci-build] building %s\n' "$name"
  if ! sbcl --noinform --no-userinit --no-sysinit --disable-debugger \
    --script "$SCRIPT_DIR/ci-build.lisp" "$BUILD_DIR/" "$name" \
    > "$BUILD_DIR/logs/$name.log" 2>&1; then
    cat "$BUILD_DIR/logs/$name.log" >&2
    fail "build failed: $name"
  fi
  "$BUILD_DIR/$name" --version
done
shasum -a 256 "$BUILD_DIR/taf" "$BUILD_DIR/taffish" "$BUILD_DIR/taffish-mcp"
