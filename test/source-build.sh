#!/bin/sh
# Check the developer build script and the three programs it produces.
set -eu

if [ "$#" -ne 2 ]; then
    printf 'Usage: sh test/source-build.sh ecl|ccl OUTPUT_DIR\n' >&2
    exit 2
fi
impl=$1
output=$2
case "$impl" in ecl|ccl) ;; *) printf 'Unknown implementation: %s\n' "$impl" >&2; exit 2 ;; esac
root=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd -P)
builder=$root/scripts/build-from-source.sh
scratch=$(mktemp -d "${TMPDIR:-/tmp}/taffish-build-test.XXXXXX")
trap 'rm -rf "$scratch"' 0
trap 'exit 1' HUP INT TERM

# A failed compiler must leave its destination available for retry.
cat > "$scratch/failing-compiler" <<'SH'
#!/bin/sh
touch "$COMPILER_CALLED"
exit 17
SH
chmod +x "$scratch/failing-compiler"
if COMPILER_CALLED="$scratch/called" ECL="$scratch/failing-compiler" CCL="$scratch/failing-compiler" \
    sh "$builder" "$impl" "$scratch/failed build"; then
    printf 'Build unexpectedly accepted compiler failure\n' >&2
    exit 1
fi
test -f "$scratch/called"
if [ -d "$scratch/failed build" ]; then
    test -z "$(find "$scratch/failed build" -mindepth 1 -print)"
fi

sh "$builder" "$impl" "$output"
bin=$(CDPATH='' cd -P "$output/bin" && pwd -P)
if sh "$builder" "$impl" "$output"; then
    printf 'Build reused an occupied output directory\n' >&2
    exit 1
fi

# The alias exercises paths with spaces even when the caller picked a simple path.
ln -s "$bin" "$scratch/programs with spaces"
bin="$scratch/programs with spaces"
set -- --taf "$bin/taf" --taffish "$bin/taffish" --taffish-mcp "$bin/taffish-mcp"
for check in binary/smoke taffish/file-args-and-defaults taf-project/run-stdin-process-boundary \
    taf-project/run-concurrent-temp-directories taf-system/command-progress-update; do
    sh "$root/test/run-tests.sh" "$@" --filter "$check"
done
