#!/bin/sh
# Split the canonical macOS archive for Gitee transport; never change its bytes.
set -eu
export LC_ALL=C
umask 022

fail() { printf 'split-release-archive: %s\n' "$*" >&2; exit 1; }
case "${1:-}" in
    --help|-h)
        echo 'Usage: split-release-archive.sh ARCHIVE'
        echo 'Create 8 MiB macOS archive parts and an ordered .parts checksum list beside ARCHIVE.'
        echo 'Existing archives, parts and release signatures are preserved.'
        exit 0 ;;
esac
[ "$#" -eq 1 ] || fail 'expected one macOS platform archive'
archive=$1
[ -f "$archive" ] && [ ! -L "$archive" ] || fail "expected a regular archive: $archive"
directory=$(CDPATH='' cd -P "$(dirname "$archive")" && pwd -P)
base=$(basename "$archive")
printf '%s\n' "$base" | grep -Eq '^taffish-[0-9]+\.[0-9]+\.[0-9]+(-[[:alnum:].-]+)?(\+[[:alnum:].-]+)?-darwin-arm64\.tar\.xz$' ||
    fail 'expected taffish-VERSION-darwin-arm64.tar.xz (Linux packages are not split)'
archive=$directory/$base
for tool in split shasum cmp; do command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"; done
size=$(wc -c < "$archive" | tr -d '[:space:]')
[ "$size" -gt 0 ] && [ "$size" -le 536870912 ] || fail 'archive must be nonempty and at most 512 MiB (64 parts)'

work=$directory/.$base.parts-lock
mkdir -m 700 "$work" || fail "could not reserve $work"
published=
complete=0
cleanup() {
    if [ "$complete" -ne 1 ]; then
        for name in $published; do rm -f "$directory/$name"; done
    fi
    rm -rf "$work"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM
for path in "$archive.parts" "$archive".part-*; do
    [ ! -e "$path" ] && [ ! -L "$path" ] || fail "output already exists: $path"
done

before=$(shasum -a 256 "$archive" | awk '{print $1}')
split -b 8388608 -a 2 "$archive" "$work/$base.part-"
set --
for path in "$work/$base".part-??; do
    [ -f "$path" ] && [ ! -L "$path" ] || fail 'split did not produce regular parts'
    set -- "$@" "${path##*/}"
done
[ "$#" -gt 0 ] && [ "$#" -le 64 ] || fail 'expected 1 to 64 parts'
(cd "$work" && cat "$@") > "$work/reassembled"
cmp -s "$archive" "$work/reassembled" || fail 'reassembled archive differs from the input'
after=$(shasum -a 256 "$archive" | awk '{print $1}')
[ "$before" = "$after" ] || fail 'archive changed during splitting'
(cd "$work" && shasum -a 256 "$@") > "$work/$base.parts"

# The shared lock serializes producers. Hard links avoid replacing existing files;
# publish the list last so its presence means every listed part is ready.
for name in "$@" "$base.parts"; do
    [ ! -e "$directory/$name" ] && [ ! -L "$directory/$name" ] || fail "output already exists: $name"
    trap '' HUP INT TERM
    if ln "$work/$name" "$directory/$name"; then
        published="$published $name"
    else
        fail "could not publish $name"
    fi
    trap 'exit 1' HUP INT TERM
done
complete=1
printf 'Prepared %s parts in %s.parts; the complete archive and signatures are unchanged.\n' "$#" "$archive"
