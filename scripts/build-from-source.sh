#!/bin/sh
# Build TAFFISH executables with ECL or Clozure CL.
set -eu

usage() {
    printf '%s\n' 'Usage: sh scripts/build-from-source.sh ecl|ccl OUTPUT_DIR' \
        'OUTPUT_DIR must be new or empty, outside the source tree; its parent must exist.' \
        'Set ECL or CCL to select a Lisp executable. Programs are written to OUTPUT_DIR/bin/.'
}

fail() {
    printf 'build-from-source: %s\n' "$*" >&2
    exit 1
}

# The directory is also the build lock. A partial publication is recognized by
# the validated staged file having moved out of bin/. Backups are hard links
# made before the first rename, so readers keep using the previous executable.
cleanup() {
    status=$?
    trap - 0
    trap '' HUP INT TERM
    if [ "$publishing" = yes ]; then
        restore_failed=no
        for name in $programs; do
            [ ! -e "$stage/bin/$name" ] || continue
            if [ -f "$stage/prior/$name" ]; then
                mv -f "$stage/prior/$name" "$output/$name" || restore_failed=yes
            else
                rm -f "$output/$name" || restore_failed=yes
            fi
        done
        if [ "$restore_failed" = yes ]; then
            printf 'Build rollback failed; previous binaries remain in %s/prior\n' "$stage" >&2
            exit 1
        fi
    fi
    rm -rf "$stage"
    exit "$status"
}

if [ "$#" -eq 1 ] && { [ "$1" = --help ] || [ "$1" = -h ]; }; then
    usage
    exit 0
fi
[ "$#" -ge 2 ] || { usage >&2; exit 1; }
case "$1" in
    ecl) compiler=${ECL:-ecl} ;;
    ccl) compiler=${CCL:-ccl} ;;
    *) fail "unknown Lisp implementation: $1" ;;
esac
impl=$1
root=$(CDPATH='' cd -P "$(dirname "$0")/.." && pwd -P)
selection=all
if [ "$#" -eq 4 ] && [ "$2" = --target ]; then
    mode=target
    selection=$3
    compiler=$4
    output=$root/target
    [ ! -L "$output" ] || fail "target must be a directory, not a symbolic link: $output"
elif [ "$#" -eq 2 ]; then
    mode=external
    [ -n "$2" ] || fail 'empty output path'
    case "$2" in /*) output=$2 ;; *) output=$PWD/$2 ;; esac
    if [ -d "$output" ]; then
        output=$(CDPATH='' cd -P "$output" && pwd -P)
    else
        parent=$(CDPATH='' cd -P "$(dirname "$output")" && pwd -P) || fail 'output parent does not exist'
        output=$parent/$(basename "$output")
    fi
    case "$output" in "$root"|"$root"/*) fail 'output must be outside the source tree' ;; esac
else
    usage >&2
    exit 1
fi

case "$selection" in
    all) programs='taf taffish taffish-mcp' ;;
    taf|taffish|taffish-mcp) programs=$selection ;;
    *) fail "unknown program: $selection" ;;
esac
compiler=$(command -v "$compiler") || fail "cannot find $impl executable"
case "$compiler" in /*) ;; *) compiler=$PWD/$compiler ;; esac
mkdir -p "$output"
stage=$output/.taffish-build
mkdir -m 700 "$stage" || fail "could not reserve staging directory: $stage"
publishing=no
trap cleanup 0
trap 'exit 1' HUP INT TERM
if [ "$mode" = external ]; then
    for entry in "$output"/* "$output"/.[!.]* "$output"/..?*; do
        [ "$entry" != "$stage" ] || continue
        if [ -e "$entry" ] || [ -L "$entry" ]; then fail 'output directory must be empty'; fi
    done
else
    mkdir "$stage/prior"
    for name in $programs; do
        dest=$output/$name
        if [ -L "$dest" ] || { [ -e "$dest" ] && [ ! -f "$dest" ]; }; then
            fail "expected a regular file or absent target: $dest"
        fi
        if [ -f "$dest" ]; then ln "$dest" "$stage/prior/$name"; fi
    done
fi

mkdir "$stage/bin" "$stage/cache"
TAFFISH_BUILD_STAGE=$stage
export TAFFISH_BUILD_STAGE
cd "$root"
case "$impl" in
    ecl)
        TAFFISH_BUILD_PROGRAM=$selection "$compiler" -norc -nodebug -shell scripts/build-from-source.lisp
        ;;
    ccl)
        # Saving a CCL image exits the process. Reuse its private ASDF cache.
        for name in $programs; do
            TAFFISH_BUILD_PROGRAM=$name "$compiler" --no-init --batch --quiet --load scripts/build-from-source.lisp
        done
        ;;
esac
for name in $programs; do
    exe=$stage/bin/$name
    [ -f "$exe" ] && [ ! -L "$exe" ] && [ -x "$exe" ] || fail "expected an executable: $exe"
    "$exe" --version
done

if [ "$mode" = target ]; then
    publishing=yes
    for name in $programs; do mv -f "$stage/bin/$name" "$output/$name"; done
    publishing=no
    printf 'Built %s in %s\n' "$programs" "$output"
else
    mv "$stage/bin" "$output/bin"
    printf 'Built programs in %s/bin\n' "$output"
fi
