#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
TEMPLATE=$SCRIPT_DIR/install-taffish.template.sh
MODE='write'

usage() {
    cat <<'EOF'
Usage:
  generate-installers.sh [--check]

Render the standalone GitHub and Gitee TAFFISH installers from the canonical
template. --check exits nonzero when tracked installers are out of date.
EOF
}

die() {
    printf '%s\n' "[TAFFISH-INSTALL-GENERATOR-ERROR] $*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --check)
            MODE=check
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

[ -f "$TEMPLATE" ] || die "template not found: $TEMPLATE"
command -v sed >/dev/null 2>&1 || die "sed is required"
command -v cmp >/dev/null 2>&1 || die "cmp is required"
command -v mktemp >/dev/null 2>&1 || die "mktemp is required"

TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/taffish-installer-generate.XXXXXX") || \
    die "failed to create temporary directory"
cleanup() {
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT INT TERM HUP

render() {
    _taf_output=$1
    _taf_name=$2
    _taf_provider=$3
    _taf_profile=$4
    _taf_profile_label=$5
    _taf_repo=$6
    _taf_provider_label=$7

    sed \
        -e "s|@INSTALLER_NAME@|$_taf_name|g" \
        -e "s|@DEFAULT_PROVIDER@|$_taf_provider|g" \
        -e "s|@DEFAULT_CONFIG_PROFILE@|$_taf_profile|g" \
        -e "s|@CONFIG_PROFILE_LABEL@|$_taf_profile_label|g" \
        -e "s|@DEFAULT_REPO@|$_taf_repo|g" \
        -e "s|@PROVIDER_LABEL@|$_taf_provider_label|g" \
        "$TEMPLATE" >"$_taf_output"

    if grep '@[A-Z][A-Z_]*@' "$_taf_output" >/dev/null 2>&1; then
        die "unresolved template placeholder in $_taf_output"
    fi
    chmod 0755 "$_taf_output"
}

check_or_install() {
    _taf_rendered=$1
    _taf_target=$2
    if [ "$MODE" = "check" ]; then
        if ! cmp -s "$_taf_rendered" "$_taf_target"; then
            printf '%s\n' "[TAFFISH-INSTALL-GENERATOR-ERROR] out of date: $_taf_target" >&2
            return 1
        fi
    else
        mv "$_taf_rendered" "$_taf_target"
        chmod 0755 "$_taf_target"
    fi
}

render "$TMP_ROOT/install-taffish.sh" \
    install-taffish.sh github '' none taffish/taffish GitHub
render "$TMP_ROOT/install-taffish.gitee.sh" \
    install-taffish.gitee.sh gitee china china taffish-org/taffish Gitee

status=0
check_or_install "$TMP_ROOT/install-taffish.sh" \
    "$SCRIPT_DIR/install-taffish.sh" || status=1
check_or_install "$TMP_ROOT/install-taffish.gitee.sh" \
    "$SCRIPT_DIR/install-taffish.gitee.sh" || status=1

if [ "$status" -ne 0 ]; then
    exit "$status"
fi

if [ "$MODE" = "check" ]; then
    printf '%s\n' "[TAFFISH-INSTALL-GENERATOR] generated installers are current"
else
    printf '%s\n' "[TAFFISH-INSTALL-GENERATOR] generated installers updated"
fi
