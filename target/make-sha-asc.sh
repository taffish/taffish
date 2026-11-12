#!/bin/sh
# Sign the six versioned programs, then prepare both platform archives.
set -eu
preferred_locale=${LC_ALL:-${LC_CTYPE:-${LANG:-}}}
export LC_ALL=C TZ=UTC0 COPYFILE_DISABLE=1
unset TAR_OPTIONS GZIP XZ_OPT XZ_DEFAULTS
umask 022
fingerprint=F86333E60BD674F159A5651AB9193F30C4247BB2
programs='taf taffish taffish-mcp'
platforms='darwin-arm64 linux-amd64'

fail() { printf 'make-sha-asc: %s\n' "$*" >&2; exit 1; }
usage() {
    echo 'Usage: ./make-sha-asc.sh [--sign-only|--package-only] [VERSION [PAYLOAD_DIR [OUTPUT_DIR]]]'
    echo '       ./make-sha-asc.sh --split-only ARCHIVE'
    echo 'Default: detect the version, sign the six programs, and create packages-VERSION beside them.'
    echo 'The macOS archive also gets 8 MiB transport parts for Gitee; Linux remains a single archive.'
    echo '--split-only creates parts from an existing macOS archive without signing or repacking.'
    echo 'Then run ./make-sha-asc.sh inside packages-VERSION to sign the archives.'
    echo 'Existing package directories are preserved; use a new OUTPUT_DIR or archive the old directory first.'
}
valid_version() {
    case "$1" in ''|*[!0-9A-Za-z.+-]*) return 1 ;; esac
    printf '%s\n' "$1" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+(-[[:alnum:].-]+)?(\+[[:alnum:].-]+)?$'
}
signing_locale() {
    for candidate_locale in "$preferred_locale" C.UTF-8 en_US.UTF-8; do
        [ -n "$candidate_locale" ] || continue
        charset=$(LC_ALL="$candidate_locale" locale charmap 2>/dev/null) || continue
        case "$charset" in UTF-8|UTF8|utf-8|utf8) printf '%s\n' "$candidate_locale"; return 0 ;; esac
    done
    fail 'GPG signing requires an installed UTF-8 locale (for example en_US.UTF-8 or C.UTF-8)'
}

here=$(CDPATH='' cd -P "$(dirname "$0")" && pwd -P)
repo=$(dirname "$here")
mode=all
case "${1:-}" in
    --help|-h) usage; exit 0 ;;
    --split-only) shift; exec sh "$repo/scripts/split-release-archive.sh" "$@" ;;
    --sign-only) mode=sign; shift ;;
    --package-only) mode=package; shift ;;
esac
case "${1:-}" in --help|-h) usage; exit 0 ;; esac
[ "$#" -le 3 ] || { usage >&2; exit 2; }
[ "$mode" != sign ] || [ "$#" -le 2 ] || fail '--sign-only does not take an output directory'
inputs=$(CDPATH='' cd -P "${2:-$here}" && pwd -P)
version=${1:-}
if [ "$#" -ge 1 ]; then
    valid_version "$version" || fail "invalid version: $version"
else
    for program in $programs; do
        for platform in $platforms; do
            prefix=$program-$platform-
            for file in "$inputs/$prefix"[0-9]*; do
                [ -f "$file" ] || continue
                candidate=${file##*/}
                candidate=${candidate#"$prefix"}
                valid_version "$candidate" || continue
                if [ -n "$version" ] && [ "$candidate" != "$version" ]; then
                    fail "found versions $version and $candidate; specify VERSION to select one"
                fi
                version=$candidate
            done
        done
    done
    [ -n "$version" ] || fail 'no versioned programs found in the payload directory'
fi
for program in $programs; do
    for platform in $platforms; do
        file=$inputs/$program-$platform-$version
        if [ ! -f "$file" ] || [ -L "$file" ]; then
            fail "expected a regular program file: $file"
        fi
    done
done

sign_programs() (
    cd "$inputs"
    manifest=SHA256SUMS
    set --
    for program in $programs; do
        for platform in $platforms; do
            file=$program-$platform-$version
            if [ ! -f "$file" ] || [ -L "$file" ]; then
                fail "expected a regular program file: $file"
            fi
            set -- "$@" "$file"
        done
    done
    for file in "$manifest" "$manifest.asc"; do
        if [ -L "$file" ] || { [ -e "$file" ] && [ ! -f "$file" ]; }; then
            fail "expected a regular file: $file"
        fi
    done

    work=$lock
    shasum -a 256 "$@" > "$work/$manifest"
    if [ -f "$manifest.asc" ] && cmp -s "$work/$manifest" "$manifest"; then
        if gpg --no-options --batch --status-fd 1 --verify "$manifest.asc" "$work/$manifest" > "$work/status" &&
           awk -v pin="$fingerprint" '$1=="[GNUPG:]" && $2=="VALIDSIG" {n++; if ($NF==pin) ok++}
               END {exit !(n==1 && ok==1)}' "$work/status"; then
            printf 'Version %s: all six programs already have a valid signature.\n' "$version"
            exit 0
        fi
    fi

    # Preserve the usual GPG overwrite prompt while signing in the staging directory.
    if [ -f "$manifest.asc" ]; then cp "$manifest.asc" "$work/$manifest.asc"; fi
    if [ -t 0 ]; then GPG_TTY=$(tty); export GPG_TTY; fi
    printf 'Signing six programs for version %s.\n' "$version"
    sign_locale=$(signing_locale)
    LC_ALL="$sign_locale" gpg --no-options --lc-ctype "$sign_locale" --lc-messages "$sign_locale" \
        --armor --local-user "$fingerprint" --detach-sign "$work/$manifest"

    if [ -f "$manifest" ]; then ln "$manifest" "$work/previous"; fi
    # Complete or roll back the two renames before handling termination.
    trap '' HUP INT TERM
    mv -f "$work/$manifest" "$manifest"
    if ! mv -f "$work/$manifest.asc" "$manifest.asc"; then
        if [ -f "$work/previous" ]; then mv -f "$work/previous" "$manifest"; else rm -f "$manifest"; fi
        fail "could not install $manifest.asc"
    fi
    printf 'Created %s and %s.asc for version %s.\n' "$manifest" "$manifest" "$version"
)

# All modes hold the same input lock through signing and packaging.
lock=$inputs/.SHA256SUMS.sign-lock
mkdir -m 700 "$lock" || fail "could not reserve $lock"
cleanup() {
    if [ -n "${package_work:-}" ]; then rm -rf "$package_work"; fi
    rm -rf "$lock"
}
trap cleanup 0
trap 'exit 1' HUP INT TERM
if [ "$mode" = sign ]; then sign_programs; exit 0; fi

output_name=packages-$version
parent=$inputs
if [ "$#" -eq 3 ]; then
    [ -n "$3" ] || fail 'empty output directory'
    parent=$(CDPATH='' cd -P "$(dirname "$3")" && pwd -P)
    output_name=$(basename "$3")
    case "$output_name" in ''|.|..|/) fail 'expected a new output directory' ;; esac
    case "$parent/$output_name/" in
        "$repo/"*|"$inputs/"*) fail 'explicit output must be outside the source and input directories' ;;
    esac
fi
output=$parent/$output_name
if [ -e "$output" ] || [ -L "$output" ]; then
    fail "output already exists: $output"
fi

# Stage on the destination filesystem. Concurrent invocations share this reservation.
work=$parent/.$output_name.package-lock
mkdir -m 700 "$work" || fail "could not reserve $work"
package_work=$work
tree=$work/tree
out=$work/out
mkdir -p "$tree/target" "$out"
mkdir -m 700 "$work/gnupg"

copy_file() {
    if [ ! -f "$1" ] || [ -L "$1" ]; then
        fail "expected a regular file: $1"
    fi
    mkdir -p "$(dirname "$tree/$2")"
    cp "$1" "$tree/$2"
    chmod "$3" "$tree/$2"
    touch -t 197001010000.00 "$tree/$2"
}

resources='LICENSE vendor/han/LICENSE completion/README.md completion/bash/taf completion/bash/taffish
completion/fish/taf.fish completion/fish/taffish.fish completion/zsh/_taf completion/zsh/_taffish
vim-highlight/README.md vim-highlight/ftdetect/taf.vim vim-highlight/syntax/old-taf.vim vim-highlight/syntax/taf.vim'
key=TAFFISH-RELEASE-KEY.asc
for tool in gpg gpgv shasum tar split cmp; do command -v "$tool" >/dev/null 2>&1 || fail "missing tool: $tool"; done
for file in $resources licenses/SBCL-NOTICES.txt licenses/LISPWORKS-RUNTIME.txt scripts/sign-release-archives.sh.in scripts/split-release-archive.sh; do
    if [ ! -f "$repo/$file" ] || [ -L "$repo/$file" ] || [ ! -s "$repo/$file" ]; then
        fail "missing or invalid release resource: $file"
    fi
done
copy_file "$inputs/$key" "target/$key" 0644

# Pin the same primary key as the installer and authenticate the staged manifest.
pin=$(sed -n 's/^TAFFISH_RELEASE_KEY_FINGERPRINT=\([0-9A-F]*\)$/\1/p' "$repo/install/install-taffish.template.sh")
if [ "${#pin}" -ne 40 ] || [ "$pin" != "$fingerprint" ]; then
    fail 'invalid or mismatched installer fingerprint'
fi
gpg --batch --no-options --no-autostart --homedir "$work/gnupg" --with-colons \
    --show-keys "$tree/target/$key" > "$work/key-info"
awk -F: -v pin="$pin" '$1=="pub" {pub++} $1=="fpr" && !first {first=$10}
    END {exit !(pub==1 && first==pin)}' "$work/key-info" || fail 'release key does not match the installer fingerprint'
gpg --batch --no-options --no-autostart --homedir "$work/gnupg" --dearmor \
    --output "$work/keyring.gpg" "$tree/target/$key"
tar_version=$(tar --version)
case "$tar_version" in
    *bsdtar*) ;;
    *'GNU tar'*)
        command -v xz >/dev/null 2>&1 || fail 'missing tool: xz'
        command -v gzip >/dev/null 2>&1 || fail 'missing tool: gzip' ;;
    *) fail 'expected bsdtar or GNU tar' ;;
esac
if [ "$mode" = all ]; then sign_programs; fi
for file in SHA256SUMS SHA256SUMS.asc; do copy_file "$inputs/$file" "target/$file" 0644; done
gpgv --homedir "$work/gnupg" --keyring "$work/keyring.gpg" --status-fd 1 \
    "$tree/target/SHA256SUMS.asc" "$tree/target/SHA256SUMS" > "$work/signature"
awk -v pin="$pin" '$1=="[GNUPG:]" && $2=="VALIDSIG" {total++; if ($NF==pin) ok++}
    END {exit !(total==1 && ok==1)}' "$work/signature" || fail 'unexpected signature on SHA256SUMS'

programs='taf taffish taffish-mcp'
set --
for platform in darwin-arm64 linux-amd64; do
    for program in $programs; do
        file=$program-$platform-$version
        copy_file "$inputs/$file" "target/$file" 0755
        set -- "$@" "$file"
    done
done
(cd "$tree/target" && shasum -a 256 "$@") > "$work/actual"
awk '
    FILENAME==ARGV[1] {
        name=$2; sub(/^\*/, "", name)
        if (NF!=2 || length($1)!=64 || $1~/[^[:xdigit:]]/ ||
            name!~/^[A-Za-z0-9._+-]+$/ || name in signed) exit 1
        signed[name]=tolower($1); next
    }
    !($2 in signed) || signed[$2]!=$1 {exit 1}
' "$tree/target/SHA256SUMS" "$work/actual" || fail 'one or more programs do not match the signed manifest'

for file in $resources licenses/SBCL-NOTICES.txt licenses/LISPWORKS-RUNTIME.txt; do
    copy_file "$repo/$file" "$file" 0644
done

make_archive() (
    platform=$1
    cd "$tree"
    set --
    for program in $programs; do set -- "$@" "target/$program-$platform-$version"; done
    set -- "$@" target/SHA256SUMS target/SHA256SUMS.asc "target/$key"
    for file in $resources; do set -- "$@" "$file"; done
    case "$platform" in
        darwin-arm64) set -- "$@" licenses/SBCL-NOTICES.txt ;;
        linux-amd64)  set -- "$@" licenses/LISPWORKS-RUNTIME.txt ;;
    esac
    archive=taffish-$version-$platform.tar
    case "$tar_version" in
        *bsdtar*)
            case "$platform" in
                darwin-arm64) ext=xz; filter=J; options=xz:compression-level=9 ;;
                linux-amd64)  ext=gz; filter=z; options=gzip:compression-level=9,gzip:!timestamp ;;
            esac
            tar "-c${filter}f" "$out/$archive.$ext" --format ustar --options "$options" \
                --uid 0 --gid 0 --uname root --gname root "$@" ;;
        *'GNU tar'*)
            tar -cf "$work/files.tar" --format=ustar --owner=0 --group=0 --numeric-owner "$@"
            case "$platform" in
                darwin-arm64) xz -9 -T1 -c "$work/files.tar" > "$out/$archive.xz" ;;
                linux-amd64)  gzip -n -9 -c "$work/files.tar" > "$out/$archive.gz" ;;
            esac ;;
        *) fail 'expected bsdtar or GNU tar' ;;
    esac
)

make_archive darwin-arm64
make_archive linux-amd64
sh "$repo/scripts/split-release-archive.sh" "$out/taffish-$version-darwin-arm64.tar.xz"
(cd "$out" && shasum -a 256 "taffish-$version-darwin-arm64.tar.xz" \
    "taffish-$version-linux-amd64.tar.gz" > ARCHIVE-SHA256SUMS)
cp "$tree/target/$key" "$out/$key"
sed -e "s/@VERSION@/$version/g" -e "s/@FINGERPRINT@/$pin/g" \
    "$repo/scripts/sign-release-archives.sh.in" > "$out/make-sha-asc.sh"
chmod 0755 "$out/make-sha-asc.sh"
if [ -e "$output" ] || [ -L "$output" ]; then
    fail "output already exists: $output"
fi
mv "$out" "$output"
printf 'Prepared %s\nRun ./make-sha-asc.sh in that directory to sign both archives.\n' "$output"
