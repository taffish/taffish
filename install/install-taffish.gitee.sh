#!/bin/sh

set -eu

TAFFISH_INSTALL_SCOPE=${TAFFISH_INSTALL_SCOPE:-user}
TAFFISH_INSTALL_PREFIX=${TAFFISH_INSTALL_PREFIX:-}
TAFFISH_INSTALL_BIN_DIR=${TAFFISH_INSTALL_BIN_DIR:-}
TAFFISH_INSTALL_HOME=${TAFFISH_INSTALL_HOME:-}
TAFFISH_INSTALL_NO_UPDATE=${TAFFISH_INSTALL_NO_UPDATE:-0}
TAFFISH_INSTALL_NO_DOCTOR=${TAFFISH_INSTALL_NO_DOCTOR:-0}
TAFFISH_INSTALL_PROVIDER=${TAFFISH_INSTALL_PROVIDER:-gitee}
TAFFISH_INSTALL_RAW_BASE_URL=${TAFFISH_INSTALL_RAW_BASE_URL:-}
TAFFISH_INSTALL_CONFIG_PROFILE=${TAFFISH_INSTALL_CONFIG_PROFILE:-china}
TAFFISH_INSTALL_CONFIG_FORCE=${TAFFISH_INSTALL_CONFIG_FORCE:-0}
TAFFISH_INSTALL_FORCE=${TAFFISH_INSTALL_FORCE:-0}
TAFFISH_INSTALL_SIF_CACHE_POLICY=${TAFFISH_INSTALL_SIF_CACHE_POLICY:-auto}
TAFFISH_INSTALL_DRY_RUN=${TAFFISH_INSTALL_DRY_RUN:-0}
TAFFISH_INSTALL_VERIFY=${TAFFISH_INSTALL_VERIFY:-auto}
TAFFISH_INSTALL_RETRY=${TAFFISH_INSTALL_RETRY:-3}
TAFFISH_INSTALL_CONNECT_TIMEOUT=${TAFFISH_INSTALL_CONNECT_TIMEOUT:-15}
TAFFISH_RELEASE_KEY_FINGERPRINT=F86333E60BD674F159A5651AB9193F30C4247BB2

REPO=taffish-org/taffish
VERSION=0.11.0
ARCHIVE=
URL=
SHARE_URL=
TAF_URL=
TAFFISH_URL=
TAFFISH_MCP_URL=
TARGET_OS_OVERRIDE=
TARGET_ARCH_OVERRIDE=
CHECKSUM_FILE=
CHECKSUM_URL=
SIGNATURE_FILE=
SIGNATURE_URL=
RELEASE_KEY_FILE=
RELEASE_KEY_URL=
TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY=
TAFFISH_INSTALL_SIF_DIR_EXISTED=0
TAFFISH_INSTALL_VERIFICATION_LEVEL=none
TAFFISH_DOWNLOADED_ASSET=
TAFFISH_VERIFY_MANIFEST=
TAFFISH_VERIFY_SIGNATURE=
TAFFISH_VERIFY_KEY=
TAFFISH_INSTALL_LOCK_DIR=
TAFFISH_INSTALL_LOCK_HELD=0
TAFFISH_INSTALL_TRANSACTION_ACTIVE=0
TAFFISH_INSTALL_TRANSACTION_DIR=
TAFFISH_INSTALL_BINARY_ACTION=installed
TAFFISH_INSTALL_SOURCE_KIND=raw
TAFFISH_INSTALL_RECEIPT_PATH=
TAFFISH_INSTALL_RECEIPT_TMP=
TAFFISH_INSTALL_SELECTED_ASSET_TAF=
TAFFISH_INSTALL_SELECTED_ASSET_TAFFISH=
TAFFISH_INSTALL_SELECTED_ASSET_MCP=
TAFFISH_POST_DOCTOR_STATUS=skipped
TAFFISH_POST_CONFIG_STATUS=skipped
TAFFISH_POST_UPDATE_STATUS=skipped
TAFFISH_TX_TAF_PLACED=0
TAFFISH_TX_TAFFISH_PLACED=0
TAFFISH_TX_MCP_PLACED=0
TAFFISH_TX_TAF_BACKED_UP=0
TAFFISH_TX_TAFFISH_BACKED_UP=0
TAFFISH_TX_MCP_BACKED_UP=0
TAFFISH_TX_RECEIPT_PLACED=0
TAFFISH_TX_RECEIPT_BACKED_UP=0

taffish_info() {
    printf '%s\n' "[TAFFISH-INSTALL] $*"
}

taffish_warn() {
    printf '%s\n' "[TAFFISH-INSTALL-WARN] $*" >&2
}

taffish_die() {
    printf '%s\n' "[TAFFISH-INSTALL-ERROR] $*" >&2
    exit 1
}

taffish_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

taffish_need_command() {
    taffish_command_exists "$1" || taffish_die "required command not found: $1"
}

taffish_to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

taffish_strip_trailing_slash() {
    _taf_value=$1
    while [ "${_taf_value%/}" != "$_taf_value" ]; do
        _taf_value=${_taf_value%/}
    done
    printf '%s\n' "$_taf_value"
}

taffish_version_tag() {
    case "$VERSION" in
        v*) printf '%s\n' "$VERSION" ;;
        *)  printf 'v%s\n' "$VERSION" ;;
    esac
}

taffish_version_plain() {
    case "$VERSION" in
        v*) printf '%s\n' "${VERSION#v}" ;;
        *)  printf '%s\n' "$VERSION" ;;
    esac
}

taffish_should_install_mcp() {
    case "$(taffish_version_plain)" in
        0.1|0.1.*|0.2|0.2.*|0.3|0.3.*) return 1 ;;
        *) return 0 ;;
    esac
}

taffish_normalize_provider() {
    _taf_provider=$(taffish_to_lower "$1")
    case "$_taf_provider" in
        github|gitee) printf '%s\n' "$_taf_provider" ;;
        *) taffish_die "unsupported provider: $1 (expected: github|gitee)" ;;
    esac
}

taffish_normalize_config_profile() {
    _taf_profile=$(taffish_to_lower "$1")
    case "$_taf_profile" in
        ""|none|off) printf '%s\n' "" ;;
        github|china) printf '%s\n' "$_taf_profile" ;;
        *) taffish_die "unsupported config profile: $1 (expected: github|china|none)" ;;
    esac
}

taffish_normalize_sif_cache_policy() {
    _taf_policy=$(taffish_to_lower "$1")
    case "$_taf_policy" in
        auto|private|admin|shared) printf '%s\n' "$_taf_policy" ;;
        *)
            taffish_die "unsupported SIF cache policy: $1 (expected: auto|private|admin|shared)"
            ;;
    esac
}

taffish_normalize_verify_mode() {
    _taf_mode=$(taffish_to_lower "$1")
    case "$_taf_mode" in
        auto|sha256|gpg|none) printf '%s\n' "$_taf_mode" ;;
        *)
            taffish_die "unsupported verification mode: $1 (expected: auto|sha256|gpg|none)"
            ;;
    esac
}

taffish_normalize_nonnegative_integer() {
    _taf_name=$1
    _taf_value=$2
    case "$_taf_value" in
        ''|*[!0-9]*) taffish_die "$_taf_name must be a non-negative integer: $_taf_value" ;;
        *) printf '%s\n' "$_taf_value" ;;
    esac
}

taffish_normalize_positive_integer() {
    _taf_name=$1
    _taf_value=$(taffish_normalize_nonnegative_integer "$1" "$2")
    [ "$_taf_value" -gt 0 ] || taffish_die "$_taf_name must be greater than zero"
    printf '%s\n' "$_taf_value"
}

taffish_normalize_target_os() {
    _taf_os_raw=$1
    _taf_os=$(taffish_to_lower "$_taf_os_raw")
    case "$_taf_os" in
        darwin|macos) printf '%s\n' "darwin" ;;
        linux) printf '%s\n' "linux" ;;
        *)
            taffish_die "unsupported --os value: $_taf_os_raw (expected: darwin|macos|linux)"
            ;;
    esac
}

taffish_normalize_target_arch() {
    _taf_arch_raw=$1
    _taf_arch=$(taffish_to_lower "$_taf_arch_raw")
    case "$_taf_arch" in
        amd64|x86_64) printf '%s\n' "amd64" ;;
        arm64|aarch64) printf '%s\n' "arm64" ;;
        *)
            taffish_die "unsupported --arch value: $_taf_arch_raw (expected: amd64|x86_64|arm64|aarch64)"
            ;;
    esac
}

taffish_try_download_file() {
    _taf_url=$1
    _taf_out=$2
    rm -f "$_taf_out"
    if taffish_command_exists curl; then
        if curl -fsSL \
            --retry "$TAFFISH_INSTALL_RETRY" \
            --connect-timeout "$TAFFISH_INSTALL_CONNECT_TIMEOUT" \
            "$_taf_url" -o "$_taf_out"; then
            return 0
        fi
    elif taffish_command_exists wget; then
        if wget -q \
            --tries "$((TAFFISH_INSTALL_RETRY + 1))" \
            --timeout "$TAFFISH_INSTALL_CONNECT_TIMEOUT" \
            -O "$_taf_out" "$_taf_url"; then
            return 0
        fi
    else
        taffish_die "curl or wget is required for download"
    fi
    rm -f "$_taf_out"
    return 1
}

taffish_url_basename() {
    _taf_url_path=${1%%\?*}
    _taf_url_path=${_taf_url_path%%\#*}
    _taf_name=${_taf_url_path##*/}
    [ -n "$_taf_name" ] || taffish_die "can't infer asset name from URL: $1"
    printf '%s\n' "$_taf_name"
}

taffish_sha256_file() {
    _taf_file=$1
    if taffish_command_exists sha256sum; then
        sha256sum "$_taf_file" | awk '{print $1}'
    elif taffish_command_exists shasum; then
        shasum -a 256 "$_taf_file" | awk '{print $1}'
    else
        taffish_die "sha256sum or shasum is required for payload verification"
    fi
}

taffish_manifest_hash() {
    _taf_manifest=$1
    _taf_asset=$2
    awk -v target="$_taf_asset" '
        NF >= 2 {
            hash = $1
            $1 = ""
            sub(/^[ \t]+/, "", $0)
            sub(/^\*/, "", $0)
            if ($0 == target) {
                count += 1
                value = hash
            }
        }
        END {
            if (count == 1) {
                print value
                exit 0
            }
            if (count > 1) exit 2
            exit 1
        }
    ' "$_taf_manifest"
}

taffish_verify_sha256_entry() {
    _taf_manifest=$1
    _taf_asset=$2
    _taf_file=$3

    if _taf_expected=$(taffish_manifest_hash "$_taf_manifest" "$_taf_asset"); then
        :
    else
        _taf_status=$?
        if [ "$_taf_status" -eq 2 ]; then
            taffish_die "checksum manifest contains duplicate entries for $_taf_asset"
        fi
        taffish_die "checksum manifest has no entry for $_taf_asset"
    fi

    case "$_taf_expected" in
        *[!0-9A-Fa-f]*|'') taffish_die "invalid SHA256 value for $_taf_asset: $_taf_expected" ;;
    esac
    [ "${#_taf_expected}" -eq 64 ] || \
        taffish_die "invalid SHA256 length for $_taf_asset"

    _taf_actual=$(taffish_sha256_file "$_taf_file")
    _taf_expected=$(taffish_to_lower "$_taf_expected")
    _taf_actual=$(taffish_to_lower "$_taf_actual")
    [ "$_taf_expected" = "$_taf_actual" ] || \
        taffish_die "SHA256 mismatch for $_taf_asset (expected $_taf_expected, got $_taf_actual)"
    taffish_info "verified SHA256: $_taf_asset"
}

taffish_normalize_fingerprint() {
    printf '%s' "$1" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]'
}

taffish_verify_gpg_manifest() {
    _taf_manifest=$1
    _taf_signature=$2
    _taf_key=$3
    taffish_command_exists gpg || taffish_die "gpg is required for --verify gpg"
    taffish_command_exists gpgv || taffish_die "gpgv is required for --verify gpg"

    _taf_gnupg=$TMPDIR_INSTALL/gnupg
    rm -rf "$_taf_gnupg"
    mkdir -p "$_taf_gnupg" || taffish_die "failed to create isolated GPG directory"
    chmod 0700 "$_taf_gnupg" || taffish_die "failed to protect isolated GPG directory"

    _taf_key_info=$_taf_gnupg/key-info
    GNUPGHOME=$_taf_gnupg gpg --batch --no-autostart \
        --with-colons --import-options show-only --dry-run --import \
        "$_taf_key" >"$_taf_key_info" 2>/dev/null || \
        taffish_die "failed to inspect release verification key"
    _taf_primary_count=$(awk -F: '$1 == "pub" {count += 1} END {print count + 0}' \
        "$_taf_key_info")
    [ "$_taf_primary_count" -eq 1 ] || \
        taffish_die "release key material must contain exactly one primary key"
    _taf_actual_fingerprint=$(awk -F: '$1 == "fpr" {print $10; exit}' \
        "$_taf_key_info")
    _taf_actual_fingerprint=$(taffish_normalize_fingerprint "$_taf_actual_fingerprint")
    _taf_expected_fingerprint=$(taffish_normalize_fingerprint "$TAFFISH_RELEASE_KEY_FINGERPRINT")
    [ -n "$_taf_actual_fingerprint" ] || taffish_die "release key has no fingerprint"
    [ "$_taf_actual_fingerprint" = "$_taf_expected_fingerprint" ] || \
        taffish_die "release key fingerprint mismatch (expected $_taf_expected_fingerprint, got $_taf_actual_fingerprint)"

    _taf_keyring=$_taf_gnupg/release-key.gpg
    GNUPGHOME=$_taf_gnupg gpg --batch --no-autostart --yes --dearmor \
        --output "$_taf_keyring" "$_taf_key" >/dev/null 2>&1 || \
        taffish_die "failed to prepare isolated release verification keyring"
    _taf_gpgv_status=$(gpgv --status-fd 1 --keyring "$_taf_keyring" \
        "$_taf_signature" "$_taf_manifest" 2>/dev/null) || \
        taffish_die "checksum manifest signature verification failed"
    _taf_validsig_count=$(printf '%s\n' "$_taf_gpgv_status" | \
        awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {count += 1} END {print count + 0}')
    [ "$_taf_validsig_count" -eq 1 ] || \
        taffish_die "checksum manifest must have exactly one valid signature"
    _taf_signer_fingerprint=$(printf '%s\n' "$_taf_gpgv_status" | \
        awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {print $NF; exit}')
    _taf_signer_fingerprint=$(taffish_normalize_fingerprint "$_taf_signer_fingerprint")
    [ "$_taf_signer_fingerprint" = "$_taf_expected_fingerprint" ] || \
        taffish_die "checksum manifest signer fingerprint mismatch (expected $_taf_expected_fingerprint, got $_taf_signer_fingerprint)"
    taffish_info "verified GPG signature: $_taf_expected_fingerprint"
}

taffish_official_raw_source_p() {
    [ -z "$TAFFISH_INSTALL_RAW_BASE_URL" ] || return 1
    [ -z "$TAF_URL" ] || return 1
    [ -z "$TAFFISH_URL" ] || return 1
    [ -z "$TAFFISH_MCP_URL" ] || return 1
    case "$TAFFISH_INSTALL_PROVIDER:$REPO" in
        github:taffish/taffish|gitee:taffish-org/taffish) return 0 ;;
        *) return 1 ;;
    esac
}

taffish_set_verification_material() {
    _taf_kind=$1
    _taf_explicit_file=$2
    _taf_explicit_url=$3
    _taf_default_path=$4
    _taf_out=$5
    TAFFISH_PREPARED_VERIFICATION_FILE=

    if [ -n "$_taf_explicit_file" ]; then
        [ -f "$_taf_explicit_file" ] || \
            taffish_die "$_taf_kind file does not exist: $_taf_explicit_file"
        cp "$_taf_explicit_file" "$_taf_out" || \
            taffish_die "failed to snapshot $_taf_kind: $_taf_explicit_file"
        TAFFISH_PREPARED_VERIFICATION_FILE=$_taf_out
        return 0
    fi
    if [ -n "$_taf_explicit_url" ]; then
        taffish_download_file "$_taf_explicit_url" "$_taf_out"
        TAFFISH_PREPARED_VERIFICATION_FILE=$_taf_out
        return 0
    fi

    _taf_url=$(taffish_raw_file_url "$_taf_default_path")
    if taffish_try_download_file "$_taf_url" "$_taf_out"; then
        TAFFISH_PREPARED_VERIFICATION_FILE=$_taf_out
        return 0
    fi
    return 1
}

taffish_prepare_remote_verification() {
    TAFFISH_VERIFY_MANIFEST=
    TAFFISH_VERIFY_SIGNATURE=
    TAFFISH_VERIFY_KEY=

    [ "$TAFFISH_INSTALL_VERIFY" != "none" ] || return 0

    _taf_try_defaults=0
    if taffish_official_raw_source_p || \
       { [ -z "$TAF_URL" ] && [ -z "$TAFFISH_URL" ] && [ -z "$TAFFISH_MCP_URL" ]; }; then
        _taf_try_defaults=1
    fi

    if [ -n "$CHECKSUM_FILE" ] || [ -n "$CHECKSUM_URL" ] || [ "$_taf_try_defaults" = "1" ]; then
        if taffish_set_verification_material \
            "checksum manifest" "$CHECKSUM_FILE" "$CHECKSUM_URL" \
            "target/SHA256SUMS" "$TMPDIR_INSTALL/SHA256SUMS"; then
            TAFFISH_VERIFY_MANIFEST=$TAFFISH_PREPARED_VERIFICATION_FILE
        elif taffish_official_raw_source_p || [ "$TAFFISH_INSTALL_VERIFY" != "auto" ]; then
            taffish_die "checksum manifest is unavailable for this source"
        fi
    elif [ "$TAFFISH_INSTALL_VERIFY" != "auto" ]; then
        taffish_die "verification mode $TAFFISH_INSTALL_VERIFY requires --checksum-file or --checksum-url for custom binary URLs"
    fi

    if [ -n "$TAFFISH_VERIFY_MANIFEST" ]; then
        if [ -n "$SIGNATURE_FILE" ] || [ -n "$SIGNATURE_URL" ] || \
           [ "$_taf_try_defaults" = "1" ]; then
            if taffish_set_verification_material \
                "checksum signature" "$SIGNATURE_FILE" "$SIGNATURE_URL" \
                "target/SHA256SUMS.asc" "$TMPDIR_INSTALL/SHA256SUMS.asc"; then
                TAFFISH_VERIFY_SIGNATURE=$TAFFISH_PREPARED_VERIFICATION_FILE
            fi
        fi
        if [ -n "$RELEASE_KEY_FILE" ] || [ -n "$RELEASE_KEY_URL" ] || \
           [ "$_taf_try_defaults" = "1" ]; then
            if taffish_set_verification_material \
                "release key" "$RELEASE_KEY_FILE" "$RELEASE_KEY_URL" \
                "target/TAFFISH-RELEASE-KEY.asc" "$TMPDIR_INSTALL/TAFFISH-RELEASE-KEY.asc"; then
                TAFFISH_VERIFY_KEY=$TAFFISH_PREPARED_VERIFICATION_FILE
            fi
        fi
    fi
}

taffish_prepare_stage_verification() {
    _taf_root=$1
    TAFFISH_VERIFY_MANIFEST=
    TAFFISH_VERIFY_SIGNATURE=
    TAFFISH_VERIFY_KEY=

    [ "$TAFFISH_INSTALL_VERIFY" != "none" ] || return 0

    if [ -n "$CHECKSUM_FILE" ]; then
        [ -f "$CHECKSUM_FILE" ] || \
            taffish_die "checksum manifest file does not exist: $CHECKSUM_FILE"
        cp "$CHECKSUM_FILE" "$TMPDIR_INSTALL/SHA256SUMS" || \
            taffish_die "failed to snapshot checksum manifest: $CHECKSUM_FILE"
        TAFFISH_VERIFY_MANIFEST=$TMPDIR_INSTALL/SHA256SUMS
    elif [ -n "$CHECKSUM_URL" ]; then
        taffish_download_file "$CHECKSUM_URL" "$TMPDIR_INSTALL/SHA256SUMS"
        TAFFISH_VERIFY_MANIFEST=$TMPDIR_INSTALL/SHA256SUMS
    elif [ -f "$_taf_root/target/SHA256SUMS" ]; then
        TAFFISH_VERIFY_MANIFEST=$_taf_root/target/SHA256SUMS
    elif [ "$TAFFISH_INSTALL_VERIFY" != "auto" ]; then
        taffish_die "verification mode $TAFFISH_INSTALL_VERIFY requires a checksum manifest"
    fi

    if [ -n "$SIGNATURE_FILE" ]; then
        [ -f "$SIGNATURE_FILE" ] || \
            taffish_die "checksum signature file does not exist: $SIGNATURE_FILE"
        cp "$SIGNATURE_FILE" "$TMPDIR_INSTALL/SHA256SUMS.asc" || \
            taffish_die "failed to snapshot checksum signature: $SIGNATURE_FILE"
        TAFFISH_VERIFY_SIGNATURE=$TMPDIR_INSTALL/SHA256SUMS.asc
    elif [ -n "$SIGNATURE_URL" ]; then
        taffish_download_file "$SIGNATURE_URL" "$TMPDIR_INSTALL/SHA256SUMS.asc"
        TAFFISH_VERIFY_SIGNATURE=$TMPDIR_INSTALL/SHA256SUMS.asc
    elif [ -f "$_taf_root/target/SHA256SUMS.asc" ]; then
        TAFFISH_VERIFY_SIGNATURE=$_taf_root/target/SHA256SUMS.asc
    fi

    if [ -n "$RELEASE_KEY_FILE" ]; then
        [ -f "$RELEASE_KEY_FILE" ] || \
            taffish_die "release key file does not exist: $RELEASE_KEY_FILE"
        cp "$RELEASE_KEY_FILE" "$TMPDIR_INSTALL/TAFFISH-RELEASE-KEY.asc" || \
            taffish_die "failed to snapshot release key: $RELEASE_KEY_FILE"
        TAFFISH_VERIFY_KEY=$TMPDIR_INSTALL/TAFFISH-RELEASE-KEY.asc
    elif [ -n "$RELEASE_KEY_URL" ]; then
        taffish_download_file "$RELEASE_KEY_URL" "$TMPDIR_INSTALL/TAFFISH-RELEASE-KEY.asc"
        TAFFISH_VERIFY_KEY=$TMPDIR_INSTALL/TAFFISH-RELEASE-KEY.asc
    elif [ -f "$_taf_root/target/TAFFISH-RELEASE-KEY.asc" ]; then
        TAFFISH_VERIFY_KEY=$_taf_root/target/TAFFISH-RELEASE-KEY.asc
    fi
}

taffish_verify_payload() {
    _taf_manifest=$1
    _taf_signature=$2
    _taf_key=$3
    shift 3

    if [ "$TAFFISH_INSTALL_VERIFY" = "none" ]; then
        TAFFISH_INSTALL_VERIFICATION_LEVEL=none
        taffish_warn "payload verification disabled explicitly"
        return 0
    fi

    if [ -z "$_taf_manifest" ]; then
        if [ "$TAFFISH_INSTALL_VERIFY" = "auto" ]; then
            TAFFISH_INSTALL_VERIFICATION_LEVEL=none
            taffish_warn "no checksum manifest is available for this custom source; payload remains unverified"
            return 0
        fi
        taffish_die "verification mode $TAFFISH_INSTALL_VERIFY requires a checksum manifest"
    fi

    while [ "$#" -gt 0 ]; do
        [ "$#" -ge 2 ] || taffish_die "internal error: incomplete verification asset pair"
        taffish_verify_sha256_entry "$_taf_manifest" "$1" "$2"
        shift 2
    done
    TAFFISH_INSTALL_VERIFICATION_LEVEL=sha256

    if [ "$TAFFISH_INSTALL_VERIFY" = "gpg" ]; then
        [ -n "$_taf_signature" ] || taffish_die "--verify gpg requires a checksum signature"
        [ -n "$_taf_key" ] || taffish_die "--verify gpg requires a release key"
        taffish_verify_gpg_manifest "$_taf_manifest" "$_taf_signature" "$_taf_key"
        TAFFISH_INSTALL_VERIFICATION_LEVEL=gpg
    elif [ "$TAFFISH_INSTALL_VERIFY" = "auto" ] && \
         [ -n "$_taf_signature" ] && [ -n "$_taf_key" ] && \
         taffish_command_exists gpg && taffish_command_exists gpgv; then
        taffish_verify_gpg_manifest "$_taf_manifest" "$_taf_signature" "$_taf_key"
        TAFFISH_INSTALL_VERIFICATION_LEVEL=gpg
    fi
}

taffish_validate_archive() {
    _taf_archive=$1
    _taf_names=$TMPDIR_INSTALL/archive-names
    _taf_listing=$TMPDIR_INSTALL/archive-listing

    tar -tzf "$_taf_archive" >"$_taf_names" || \
        taffish_die "failed to list archive: $_taf_archive"
    while IFS= read -r _taf_entry; do
        case "$_taf_entry" in
            /*|../*|*/../*|*/..|..)
                taffish_die "unsafe archive path: $_taf_entry"
                ;;
        esac
    done <"$_taf_names"

    tar -tvzf "$_taf_archive" >"$_taf_listing" || \
        taffish_die "failed to inspect archive entry types: $_taf_archive"
    while IFS= read -r _taf_line; do
        _taf_type=$(printf '%s' "$_taf_line" | cut -c 1)
        case "$_taf_type" in
            -|d) ;;
            *) taffish_die "unsafe archive entry type: $_taf_line" ;;
        esac
    done <"$_taf_listing"
}

taffish_download_file() {
    _taf_url=$1
    _taf_out=$2
    taffish_info "downloading $_taf_url"
    taffish_try_download_file "$_taf_url" "$_taf_out" || \
        taffish_die "download failed: $_taf_url"
}

taffish_dirname() {
    dirname "$1"
}

taffish_detect_os() {
    case "$(uname -s 2>/dev/null || printf unknown)" in
        Linux)  printf '%s\n' "linux" ;;
        Darwin) printf '%s\n' "macos" ;;
        *)      taffish_die "unsupported OS: $(uname -s 2>/dev/null || printf unknown)" ;;
    esac
}

taffish_detect_arch() {
    _taf_os=$1
    _taf_machine=$(uname -m 2>/dev/null || printf unknown)
    case "$_taf_machine" in
        x86_64|amd64)
            printf '%s\n' "x86_64"
            ;;
        arm64|aarch64)
            if [ "$_taf_os" = "macos" ]; then
                printf '%s\n' "arm64"
            else
                printf '%s\n' "aarch64"
            fi
            ;;
        *)
            taffish_die "unsupported architecture: $_taf_machine"
            ;;
    esac
}

taffish_detect_target_os() {
    if [ -n "$TARGET_OS_OVERRIDE" ]; then
        taffish_normalize_target_os "$TARGET_OS_OVERRIDE"
        return 0
    fi
    case "$(uname -s 2>/dev/null || printf unknown)" in
        Linux)  printf '%s\n' "linux" ;;
        Darwin) printf '%s\n' "darwin" ;;
        *)      taffish_die "unsupported OS for target binaries: $(uname -s 2>/dev/null || printf unknown)" ;;
    esac
}

taffish_detect_target_arch() {
    if [ -n "$TARGET_ARCH_OVERRIDE" ]; then
        taffish_normalize_target_arch "$TARGET_ARCH_OVERRIDE"
        return 0
    fi
    _taf_machine=$(uname -m 2>/dev/null || printf unknown)
    case "$_taf_machine" in
        x86_64|amd64) printf '%s\n' "amd64" ;;
        arm64|aarch64) printf '%s\n' "arm64" ;;
        *) taffish_die "unsupported architecture for target binaries: $_taf_machine" ;;
    esac
}

taffish_target_os_aliases() {
    case "$1" in
        darwin) printf '%s\n' "darwin macos" ;;
        linux)  printf '%s\n' "linux" ;;
        *)      printf '%s\n' "$1" ;;
    esac
}

taffish_target_arch_aliases() {
    case "$1" in
        amd64) printf '%s\n' "amd64 x86_64" ;;
        arm64) printf '%s\n' "arm64 aarch64" ;;
        *)     printf '%s\n' "$1" ;;
    esac
}

taffish_last_glob_match() {
    _taf_pattern=$1
    _taf_last=
    # shellcheck disable=SC2086
    for _taf_path in $_taf_pattern; do
        [ -e "$_taf_path" ] || continue
        _taf_last=$_taf_path
    done
    [ -n "$_taf_last" ] || return 1
    printf '%s\n' "$_taf_last"
}

taffish_select_target_binary() {
    _taf_target_dir=$1
    _taf_name=$2

    [ -d "$_taf_target_dir" ] || return 1

    _taf_os=$(taffish_detect_target_os)
    _taf_arch=$(taffish_detect_target_arch)

    for _taf_os_alias in $(taffish_target_os_aliases "$_taf_os"); do
        for _taf_arch_alias in $(taffish_target_arch_aliases "$_taf_arch"); do
            if [ -f "$_taf_target_dir/$_taf_name-$_taf_os_alias-$_taf_arch_alias" ]; then
                printf '%s\n' "$_taf_target_dir/$_taf_name-$_taf_os_alias-$_taf_arch_alias"
                return 0
            fi
            _taf_match=$(taffish_last_glob_match "$_taf_target_dir/$_taf_name-$_taf_os_alias-$_taf_arch_alias-*") || _taf_match=
            if [ -n "$_taf_match" ]; then
                printf '%s\n' "$_taf_match"
                return 0
            fi
        done
    done

    if [ -f "$_taf_target_dir/$_taf_name" ]; then
        printf '%s\n' "$_taf_target_dir/$_taf_name"
        return 0
    fi

    return 1
}

taffish_home_dir() {
    if [ -n "${HOME:-}" ]; then
        printf '%s\n' "$HOME"
    else
        taffish_die "HOME is not set; use --taffish-home and --bin-dir explicitly"
    fi
}

taffish_default_user_home() {
    if [ -n "${TAFFISH_USER_HOME:-}" ]; then
        printf '%s\n' "$TAFFISH_USER_HOME"
    else
        printf '%s\n' "$(taffish_home_dir)/.local/share/taffish"
    fi
}

taffish_default_system_home() {
    if [ -n "${TAFFISH_SYSTEM_HOME:-}" ]; then
        printf '%s\n' "$TAFFISH_SYSTEM_HOME"
    else
        printf '%s\n' "/opt/taffish"
    fi
}

taffish_default_system_bin_dir() {
    if [ -n "${TAFFISH_SYSTEM_BIN_DIR:-}" ]; then
        printf '%s\n' "$TAFFISH_SYSTEM_BIN_DIR"
    else
        printf '%s\n' "/usr/local/bin"
    fi
}

taffish_current_uid() {
    if [ -x /usr/bin/id ]; then
        /usr/bin/id -u
    elif [ -x /bin/id ]; then
        /bin/id -u
    else
        id -u
    fi
}

taffish_root_user_p() {
    [ "$(taffish_current_uid 2>/dev/null || printf unknown)" = "0" ]
}

taffish_effective_sif_cache_policy() {
    _taf_policy=$TAFFISH_INSTALL_SIF_CACHE_POLICY
    if [ "$_taf_policy" = "auto" ]; then
        if [ "$TAFFISH_INSTALL_SCOPE" = "user" ]; then
            _taf_policy='private'
        else
            _taf_policy='admin'
        fi
    fi

    case "$_taf_policy:$TAFFISH_INSTALL_SCOPE" in
        private:user|admin:system|shared:system)
            printf '%s\n' "$_taf_policy"
            ;;
        private:system)
            taffish_die "SIF cache policy private is only valid with --user"
            ;;
        admin:user|shared:user)
            taffish_die "SIF cache policy $_taf_policy is only valid with --system"
            ;;
        *)
            taffish_die "invalid SIF cache policy/scope combination: $_taf_policy/$TAFFISH_INSTALL_SCOPE"
            ;;
    esac
}

taffish_preflight_scope() {
    if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
        if [ "$TAFFISH_INSTALL_DRY_RUN" != "1" ] && ! taffish_root_user_p; then
            taffish_die "--system requires root privileges; run the installer through sudo"
        fi
    elif taffish_root_user_p; then
        taffish_warn "installing user scope as root; this installs into root's user home. Use --system for all users."
    fi

    TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY=$(taffish_effective_sif_cache_policy)
    export TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY
}

taffish_resolve_install_paths() {
    case "$TAFFISH_INSTALL_SCOPE" in
        user|system) ;;
        *) taffish_die "invalid install scope: $TAFFISH_INSTALL_SCOPE" ;;
    esac

    if [ -n "$TAFFISH_INSTALL_PREFIX" ]; then
        if [ -z "$TAFFISH_INSTALL_BIN_DIR" ]; then
            TAFFISH_INSTALL_BIN_DIR=$TAFFISH_INSTALL_PREFIX/bin
        fi
        if [ -z "$TAFFISH_INSTALL_HOME" ]; then
            TAFFISH_INSTALL_HOME=$TAFFISH_INSTALL_PREFIX/share/taffish
        fi
    fi

    if [ "$TAFFISH_INSTALL_SCOPE" = "user" ]; then
        if [ -z "$TAFFISH_INSTALL_BIN_DIR" ]; then
            TAFFISH_INSTALL_BIN_DIR=$(taffish_home_dir)/.local/bin
        fi
        if [ -z "$TAFFISH_INSTALL_HOME" ]; then
            TAFFISH_INSTALL_HOME=$(taffish_default_user_home)
        fi
    else
        if [ -z "$TAFFISH_INSTALL_BIN_DIR" ]; then
            TAFFISH_INSTALL_BIN_DIR=$(taffish_default_system_bin_dir)
        fi
        if [ -z "$TAFFISH_INSTALL_HOME" ]; then
            TAFFISH_INSTALL_HOME=$(taffish_default_system_home)
        fi
    fi

    export TAFFISH_INSTALL_BIN_DIR
    export TAFFISH_INSTALL_HOME
}

taffish_required_home_dirs() {
    cat <<'EOF'
apps
index
index/snapshots
images
images/sif
images/metadata
images/locks
images/tmp
bin
cache
cache/repos
cache/downloads
cache/build
logs
share
share/completions
share/completions/bash
share/completions/zsh
share/completions/fish
share/vim
share/vim/syntax
share/vim/ftdetect
EOF
}

taffish_directory_mode() {
    _taf_dir=$1
    if stat -c '%a' "$_taf_dir" >/dev/null 2>&1; then
        stat -c '%a' "$_taf_dir"
    elif stat -f '%Mp%Lp' "$_taf_dir" >/dev/null 2>&1; then
        stat -f '%Mp%Lp' "$_taf_dir"
    else
        return 1
    fi
}

taffish_apply_sif_cache_policy() {
    _taf_sif_dir=$TAFFISH_INSTALL_HOME/images/sif
    _taf_policy=$TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY

    case "$_taf_policy" in
        private)
            if [ "$TAFFISH_INSTALL_SIF_DIR_EXISTED" = "0" ]; then
                chmod 0700 "$_taf_sif_dir" || \
                    taffish_die "failed to set private SIF cache permissions: $_taf_sif_dir"
            fi
            ;;
        admin)
            if [ "$TAFFISH_INSTALL_SIF_DIR_EXISTED" = "0" ]; then
                chmod 0755 "$_taf_sif_dir" || \
                    taffish_die "failed to set administrator-managed SIF cache permissions: $_taf_sif_dir"
            fi
            ;;
        shared)
            chmod 1777 "$_taf_sif_dir" || \
                taffish_die "failed to set shared SIF cache permissions: $_taf_sif_dir"
            _taf_mode=$(taffish_directory_mode "$_taf_sif_dir" || true)
            [ "$_taf_mode" = "1777" ] || \
                taffish_die "shared SIF cache mode verification failed for $_taf_sif_dir (got: ${_taf_mode:-unknown})"
            taffish_warn "shared SIF cache enabled at $_taf_sif_dir (mode 1777); use only on a trusted multi-user host"
            ;;
        *)
            taffish_die "internal error: unresolved SIF cache policy: $_taf_policy"
            ;;
    esac
}

taffish_make_required_dirs() {
    if [ -d "$TAFFISH_INSTALL_HOME/images/sif" ]; then
        TAFFISH_INSTALL_SIF_DIR_EXISTED=1
    else
        TAFFISH_INSTALL_SIF_DIR_EXISTED=0
    fi
    mkdir -p "$TAFFISH_INSTALL_BIN_DIR" || taffish_die "failed to create bin dir: $TAFFISH_INSTALL_BIN_DIR"
    mkdir -p "$TAFFISH_INSTALL_HOME" || taffish_die "failed to create TAFFISH home: $TAFFISH_INSTALL_HOME"
    taffish_required_home_dirs | while IFS= read -r _taf_dir; do
        [ -n "$_taf_dir" ] || continue
        mkdir -p "$TAFFISH_INSTALL_HOME/$_taf_dir" || exit 1
    done
    taffish_apply_sif_cache_policy
}

taffish_prepare_install_home() {
    mkdir -p "$TAFFISH_INSTALL_HOME" || \
        taffish_die "failed to create TAFFISH home: $TAFFISH_INSTALL_HOME"
}

taffish_print_dry_run() {
    taffish_info "dry-run install plan"
    printf '  scope             : %s\n' "$TAFFISH_INSTALL_SCOPE"
    printf '  bin dir           : %s\n' "$TAFFISH_INSTALL_BIN_DIR"
    printf '  TAFFISH home      : %s\n' "$TAFFISH_INSTALL_HOME"
    printf '  provider          : %s\n' "$TAFFISH_INSTALL_PROVIDER"
    printf '  source tag        : %s\n' "$(taffish_version_tag)"
    printf '  SIF cache policy  : %s\n' "$TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY"
    printf '  verification      : %s\n' "$TAFFISH_INSTALL_VERIFY"
    printf '  download retries  : %s\n' "$TAFFISH_INSTALL_RETRY"
    printf '  connect timeout   : %ss\n' "$TAFFISH_INSTALL_CONNECT_TIMEOUT"
    printf '  network           : disabled\n'
    printf '  filesystem writes : disabled\n'
}

taffish_install_file() {
    _taf_src=$1
    _taf_dst=$2
    _taf_mode=$3

    [ -f "$_taf_src" ] || taffish_die "source file does not exist: $_taf_src"
    mkdir -p "$(taffish_dirname "$_taf_dst")" || taffish_die "failed to create parent directory for $_taf_dst"
    cp "$_taf_src" "$_taf_dst" || taffish_die "failed to copy $_taf_src to $_taf_dst"
    chmod "$_taf_mode" "$_taf_dst" || taffish_die "failed to chmod $_taf_mode $_taf_dst"
}

taffish_acquire_install_lock() {
    TAFFISH_INSTALL_LOCK_DIR=$TAFFISH_INSTALL_HOME/.installer.lock
    if mkdir "$TAFFISH_INSTALL_LOCK_DIR" 2>/dev/null; then
        TAFFISH_INSTALL_LOCK_HELD=1
        printf '%s\n' "$(taffish_current_uid):$$" > \
            "$TAFFISH_INSTALL_LOCK_DIR/owner" 2>/dev/null || true
        return 0
    fi
    taffish_die "another installer may be active for $TAFFISH_INSTALL_HOME; remove $TAFFISH_INSTALL_LOCK_DIR only after confirming that no installer is running"
}

taffish_release_install_lock() {
    [ "$TAFFISH_INSTALL_LOCK_HELD" = "1" ] || return 0
    rm -f "$TAFFISH_INSTALL_LOCK_DIR/owner"
    rmdir "$TAFFISH_INSTALL_LOCK_DIR" 2>/dev/null || true
    TAFFISH_INSTALL_LOCK_HELD=0
}

taffish_existing_command_p() {
    _taf_existing_path=$1
    _taf_existing_name=$2
    [ -f "$_taf_existing_path" ] || return 1
    [ ! -L "$_taf_existing_path" ] || return 1
    [ -x "$_taf_existing_path" ] || return 1
    _taf_existing_output=$("$_taf_existing_path" --version </dev/null 2>/dev/null) || return 1
    _taf_existing_first=$(printf '%s\n' "$_taf_existing_output" | sed -n '1p')
    case "$_taf_existing_first" in
        "$_taf_existing_name"*) return 0 ;;
        *) return 1 ;;
    esac
}

taffish_check_destination() {
    _taf_destination=$1
    _taf_name=$2
    if [ ! -e "$_taf_destination" ] && [ ! -L "$_taf_destination" ]; then
        return 0
    fi
    [ ! -d "$_taf_destination" ] || \
        taffish_die "refusing to replace directory at command path: $_taf_destination"
    if taffish_existing_command_p "$_taf_destination" "$_taf_name"; then
        return 0
    fi
    [ "$TAFFISH_INSTALL_FORCE" = "1" ] || \
        taffish_die "refusing to replace non-TAFFISH command: $_taf_destination (use --force only after checking the path)"
    [ -f "$_taf_destination" ] || [ -L "$_taf_destination" ] || \
        taffish_die "refusing to replace special file at command path: $_taf_destination"
    taffish_warn "forcing replacement of unrecognized command path: $_taf_destination"
}

taffish_smoke_candidate() {
    _taf_candidate=$1
    _taf_name=$2
    _taf_expected_version=$(taffish_version_plain)
    _taf_smoke_output=$("$_taf_candidate" --version </dev/null 2>&1) || \
        taffish_die "candidate smoke test failed: $_taf_name --version"
    _taf_smoke_first=$(printf '%s\n' "$_taf_smoke_output" | sed -n '1p')
    case "$_taf_smoke_first" in
        "$_taf_name"*"$_taf_expected_version"*) ;;
        *)
            taffish_die "candidate version mismatch for $_taf_name (expected $_taf_expected_version, got: $_taf_smoke_first)"
            ;;
    esac
    taffish_info "candidate smoke passed: $_taf_name $_taf_expected_version"
}

taffish_same_file_content_p() {
    _taf_left=$1
    _taf_right=$2
    [ -f "$_taf_left" ] || return 1
    [ -f "$_taf_right" ] || return 1
    [ "$(taffish_sha256_file "$_taf_left")" = "$(taffish_sha256_file "$_taf_right")" ]
}

taffish_rollback_binary_transaction() {
    [ "$TAFFISH_INSTALL_TRANSACTION_ACTIVE" = "1" ] || return 0
    taffish_warn "rolling back incomplete core binary installation"
    _taf_rollback_failed=0

    if [ "$TAFFISH_TX_RECEIPT_PLACED" = "1" ]; then
        if ! rm -f "$TAFFISH_INSTALL_RECEIPT_PATH"; then
            taffish_warn "rollback could not remove the incomplete install receipt: $TAFFISH_INSTALL_RECEIPT_PATH"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_RECEIPT_BACKED_UP" = "1" ]; then
        if ! mv "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-install-receipt.toml" \
            "$TAFFISH_INSTALL_RECEIPT_PATH"; then
            taffish_warn "rollback could not restore the previous install receipt"
            _taf_rollback_failed=1
        fi
    fi

    if [ "$TAFFISH_TX_MCP_PLACED" = "1" ]; then
        if ! rm -f "$TAFFISH_INSTALL_BIN_DIR/taffish-mcp"; then
            taffish_warn "rollback could not remove the incomplete taffish-mcp binary"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_MCP_BACKED_UP" = "1" ]; then
        if ! mv "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taffish-mcp" \
            "$TAFFISH_INSTALL_BIN_DIR/taffish-mcp"; then
            taffish_warn "rollback could not restore the previous taffish-mcp binary"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_TAFFISH_PLACED" = "1" ]; then
        if ! rm -f "$TAFFISH_INSTALL_BIN_DIR/taffish"; then
            taffish_warn "rollback could not remove the incomplete taffish binary"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_TAFFISH_BACKED_UP" = "1" ]; then
        if ! mv "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taffish" \
            "$TAFFISH_INSTALL_BIN_DIR/taffish"; then
            taffish_warn "rollback could not restore the previous taffish binary"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_TAF_PLACED" = "1" ]; then
        if ! rm -f "$TAFFISH_INSTALL_BIN_DIR/taf"; then
            taffish_warn "rollback could not remove the incomplete taf binary"
            _taf_rollback_failed=1
        fi
    fi
    if [ "$TAFFISH_TX_TAF_BACKED_UP" = "1" ]; then
        if ! mv "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taf" \
            "$TAFFISH_INSTALL_BIN_DIR/taf"; then
            taffish_warn "rollback could not restore the previous taf binary"
            _taf_rollback_failed=1
        fi
    fi

    TAFFISH_INSTALL_TRANSACTION_ACTIVE=0
    if [ "$_taf_rollback_failed" = "0" ]; then
        [ -z "$TAFFISH_INSTALL_TRANSACTION_DIR" ] || \
            rm -rf "$TAFFISH_INSTALL_TRANSACTION_DIR"
        TAFFISH_INSTALL_TRANSACTION_DIR=
    else
        taffish_warn "rollback was incomplete; recovery files were retained at: $TAFFISH_INSTALL_TRANSACTION_DIR"
    fi
}

taffish_finalize_binary_transaction() {
    [ "$TAFFISH_INSTALL_TRANSACTION_ACTIVE" = "1" ] || return 0
    TAFFISH_INSTALL_TRANSACTION_ACTIVE=0
    if ! rm -rf "$TAFFISH_INSTALL_TRANSACTION_DIR"; then
        taffish_warn "installed binaries are committed, but transaction cleanup failed: $TAFFISH_INSTALL_TRANSACTION_DIR"
        return 0
    fi
    TAFFISH_INSTALL_TRANSACTION_DIR=
}

taffish_install_binaries_transactionally() {
    TAFFISH_TX_SRC_TAF=$1
    TAFFISH_TX_SRC_TAFFISH=$2
    TAFFISH_TX_SRC_MCP=${3:-}
    TAFFISH_TX_DST_TAF=$TAFFISH_INSTALL_BIN_DIR/taf
    TAFFISH_TX_DST_TAFFISH=$TAFFISH_INSTALL_BIN_DIR/taffish
    TAFFISH_TX_DST_MCP=$TAFFISH_INSTALL_BIN_DIR/taffish-mcp

    if taffish_same_file_content_p "$TAFFISH_TX_SRC_TAF" "$TAFFISH_TX_DST_TAF" && \
       taffish_same_file_content_p "$TAFFISH_TX_SRC_TAFFISH" "$TAFFISH_TX_DST_TAFFISH" && \
       { [ -z "$TAFFISH_TX_SRC_MCP" ] || \
         taffish_same_file_content_p "$TAFFISH_TX_SRC_MCP" "$TAFFISH_TX_DST_MCP"; }; then
        TAFFISH_INSTALL_BINARY_ACTION=unchanged
        taffish_info "core binaries already match the requested release"
        return 0
    fi

    taffish_check_destination "$TAFFISH_TX_DST_TAF" taf
    taffish_check_destination "$TAFFISH_TX_DST_TAFFISH" taffish
    if [ -n "$TAFFISH_TX_SRC_MCP" ]; then
        taffish_check_destination "$TAFFISH_TX_DST_MCP" taffish-mcp
    fi

    TAFFISH_INSTALL_TRANSACTION_DIR=$(mktemp -d \
        "$TAFFISH_INSTALL_BIN_DIR/.taffish-install.XXXXXX") || \
        taffish_die "failed to create transaction directory in $TAFFISH_INSTALL_BIN_DIR"
    cp "$TAFFISH_TX_SRC_TAF" "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taf" || \
        taffish_die "failed to stage taf binary"
    cp "$TAFFISH_TX_SRC_TAFFISH" "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish" || \
        taffish_die "failed to stage taffish binary"
    chmod 0755 "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taf" \
        "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish" || \
        taffish_die "failed to mark staged core binaries executable"
    if [ -n "$TAFFISH_TX_SRC_MCP" ]; then
        cp "$TAFFISH_TX_SRC_MCP" "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish-mcp" || \
            taffish_die "failed to stage taffish-mcp binary"
        chmod 0755 "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish-mcp" || \
            taffish_die "failed to mark staged taffish-mcp executable"
    fi

    taffish_smoke_candidate "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taf" taf
    taffish_smoke_candidate "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish" taffish
    if [ -n "$TAFFISH_TX_SRC_MCP" ]; then
        taffish_smoke_candidate "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish-mcp" taffish-mcp
    fi

    TAFFISH_TX_TAF_PLACED=0
    TAFFISH_TX_TAFFISH_PLACED=0
    TAFFISH_TX_MCP_PLACED=0
    TAFFISH_TX_TAF_BACKED_UP=0
    TAFFISH_TX_TAFFISH_BACKED_UP=0
    TAFFISH_TX_MCP_BACKED_UP=0
    TAFFISH_TX_RECEIPT_PLACED=0
    TAFFISH_TX_RECEIPT_BACKED_UP=0
    TAFFISH_INSTALL_TRANSACTION_ACTIVE=1

    TAFFISH_INSTALL_RECEIPT_PATH=$TAFFISH_INSTALL_HOME/install-receipt.toml
    if [ -e "$TAFFISH_INSTALL_RECEIPT_PATH" ] || [ -L "$TAFFISH_INSTALL_RECEIPT_PATH" ]; then
        if [ ! -f "$TAFFISH_INSTALL_RECEIPT_PATH" ] || [ -L "$TAFFISH_INSTALL_RECEIPT_PATH" ]; then
            taffish_die "refusing to replace non-regular install receipt: $TAFFISH_INSTALL_RECEIPT_PATH"
        fi
        cp "$TAFFISH_INSTALL_RECEIPT_PATH" \
            "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-install-receipt.toml" || \
            taffish_die "failed to back up existing install receipt"
        TAFFISH_TX_RECEIPT_BACKED_UP=1
    fi

    if [ -e "$TAFFISH_TX_DST_TAF" ] || [ -L "$TAFFISH_TX_DST_TAF" ]; then
        mv "$TAFFISH_TX_DST_TAF" "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taf" || \
            taffish_die "failed to back up existing taf binary"
        TAFFISH_TX_TAF_BACKED_UP=1
    fi
    if [ -e "$TAFFISH_TX_DST_TAFFISH" ] || [ -L "$TAFFISH_TX_DST_TAFFISH" ]; then
        mv "$TAFFISH_TX_DST_TAFFISH" "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taffish" || \
            taffish_die "failed to back up existing taffish binary"
        TAFFISH_TX_TAFFISH_BACKED_UP=1
    fi
    if [ -n "$TAFFISH_TX_SRC_MCP" ] && \
       { [ -e "$TAFFISH_TX_DST_MCP" ] || [ -L "$TAFFISH_TX_DST_MCP" ]; }; then
        mv "$TAFFISH_TX_DST_MCP" "$TAFFISH_INSTALL_TRANSACTION_DIR/backup-taffish-mcp" || \
            taffish_die "failed to back up existing taffish-mcp binary"
        TAFFISH_TX_MCP_BACKED_UP=1
    fi

    mv "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taf" "$TAFFISH_TX_DST_TAF" || \
        taffish_die "failed to install taf binary"
    TAFFISH_TX_TAF_PLACED=1
    mv "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish" "$TAFFISH_TX_DST_TAFFISH" || \
        taffish_die "failed to install taffish binary"
    TAFFISH_TX_TAFFISH_PLACED=1
    if [ -n "$TAFFISH_TX_SRC_MCP" ]; then
        mv "$TAFFISH_INSTALL_TRANSACTION_DIR/new-taffish-mcp" "$TAFFISH_TX_DST_MCP" || \
            taffish_die "failed to install taffish-mcp binary"
        TAFFISH_TX_MCP_PLACED=1
    fi

    TAFFISH_INSTALL_BINARY_ACTION=installed
}

taffish_copy_tree_files() {
    _taf_src_dir=$1
    _taf_dst_dir=$2

    [ -d "$_taf_src_dir" ] || return 0
    find "$_taf_src_dir" -type f | while IFS= read -r _taf_file; do
        _taf_rel=${_taf_file#"$_taf_src_dir"/}
        taffish_install_file "$_taf_file" "$_taf_dst_dir/$_taf_rel" 0644
    done
}

taffish_receipt_value() {
    printf '%s' "$1" | tr '\r\n' '  ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

taffish_write_install_receipt() {
    TAFFISH_INSTALL_RECEIPT_PATH=$TAFFISH_INSTALL_HOME/install-receipt.toml
    if [ -e "$TAFFISH_INSTALL_RECEIPT_PATH" ] || [ -L "$TAFFISH_INSTALL_RECEIPT_PATH" ]; then
        if [ ! -f "$TAFFISH_INSTALL_RECEIPT_PATH" ] || [ -L "$TAFFISH_INSTALL_RECEIPT_PATH" ]; then
            taffish_die "refusing to replace non-regular install receipt: $TAFFISH_INSTALL_RECEIPT_PATH"
        fi
    fi
    _taf_receipt_tmp=$(mktemp "$TAFFISH_INSTALL_HOME/.install-receipt.XXXXXX") || \
        taffish_die "failed to create install receipt staging file"
    TAFFISH_INSTALL_RECEIPT_TMP=$_taf_receipt_tmp
    _taf_receipt_version=$(taffish_receipt_value "$(taffish_version_plain)")
    _taf_receipt_scope=$(taffish_receipt_value "$TAFFISH_INSTALL_SCOPE")
    _taf_receipt_provider=$(taffish_receipt_value "$TAFFISH_INSTALL_PROVIDER")
    _taf_receipt_repo=$(taffish_receipt_value "$REPO")
    _taf_receipt_source=$(taffish_receipt_value "$TAFFISH_INSTALL_SOURCE_KIND")
    _taf_receipt_verification=$(taffish_receipt_value "$TAFFISH_INSTALL_VERIFICATION_LEVEL")
    _taf_receipt_sif=$(taffish_receipt_value "$TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY")
    _taf_receipt_action=$(taffish_receipt_value "$TAFFISH_INSTALL_BINARY_ACTION")
    _taf_receipt_taf_asset=$(taffish_receipt_value "$TAFFISH_INSTALL_SELECTED_ASSET_TAF")
    _taf_receipt_taffish_asset=$(taffish_receipt_value "$TAFFISH_INSTALL_SELECTED_ASSET_TAFFISH")
    _taf_receipt_mcp_asset=$(taffish_receipt_value "$TAFFISH_INSTALL_SELECTED_ASSET_MCP")
    _taf_receipt_taf_hash=$(taffish_sha256_file "$TAFFISH_INSTALL_BIN_DIR/taf")
    _taf_receipt_taffish_hash=$(taffish_sha256_file "$TAFFISH_INSTALL_BIN_DIR/taffish")
    _taf_receipt_mcp_hash=
    if taffish_should_install_mcp; then
        _taf_receipt_mcp_hash=$(taffish_sha256_file "$TAFFISH_INSTALL_BIN_DIR/taffish-mcp")
    fi
    _taf_receipt_manifest_hash=
    if [ -n "$TAFFISH_VERIFY_MANIFEST" ]; then
        _taf_receipt_manifest_hash=$(taffish_sha256_file "$TAFFISH_VERIFY_MANIFEST")
    fi
    _taf_receipt_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf unknown)

    if ! cat >"$_taf_receipt_tmp" <<EOF
format_version = 1
installed_at_utc = "$_taf_receipt_time"
version = "$_taf_receipt_version"
scope = "$_taf_receipt_scope"
provider = "$_taf_receipt_provider"
repository = "$_taf_receipt_repo"
source_kind = "$_taf_receipt_source"
verification = "$_taf_receipt_verification"
sif_cache_policy = "$_taf_receipt_sif"
binary_action = "$_taf_receipt_action"
checksum_manifest_sha256 = "$_taf_receipt_manifest_hash"
taf_asset = "$_taf_receipt_taf_asset"
taf_sha256 = "$_taf_receipt_taf_hash"
taffish_asset = "$_taf_receipt_taffish_asset"
taffish_sha256 = "$_taf_receipt_taffish_hash"
taffish_mcp_asset = "$_taf_receipt_mcp_asset"
taffish_mcp_sha256 = "$_taf_receipt_mcp_hash"
EOF
    then
        taffish_die "failed to write install receipt"
    fi
    if ! chmod 0644 "$_taf_receipt_tmp"; then
        taffish_die "failed to protect install receipt"
    fi
    if ! mv "$_taf_receipt_tmp" "$TAFFISH_INSTALL_RECEIPT_PATH"; then
        taffish_die "failed to commit install receipt"
    fi
    TAFFISH_INSTALL_RECEIPT_TMP=
    if [ "$TAFFISH_INSTALL_TRANSACTION_ACTIVE" = "1" ]; then
        TAFFISH_TX_RECEIPT_PLACED=1
    fi
}

taffish_stage_has_target_layout() {
    _taf_root=$1
    [ -d "$_taf_root/target" ] || return 1
    taffish_select_target_binary "$_taf_root/target" taf >/dev/null 2>&1 || return 1
    taffish_select_target_binary "$_taf_root/target" taffish >/dev/null 2>&1 || return 1
    if taffish_should_install_mcp; then
        taffish_select_target_binary "$_taf_root/target" taffish-mcp >/dev/null 2>&1 || return 1
    fi
    return 0
}

taffish_stage_has_bin_layout() {
    _taf_root=$1
    [ -f "$_taf_root/bin/taf" ] || return 1
    [ -f "$_taf_root/bin/taffish" ] || return 1
    if taffish_should_install_mcp; then
        [ -f "$_taf_root/bin/taffish-mcp" ] || return 1
    fi
    return 0
}

taffish_stage_root() {
    _taf_stage=$1
    [ -d "$_taf_stage" ] || taffish_die "stage directory does not exist: $_taf_stage"

    if taffish_stage_has_bin_layout "$_taf_stage"; then
        printf '%s\n' "$_taf_stage"
        return 0
    fi
    if taffish_stage_has_target_layout "$_taf_stage"; then
        printf '%s\n' "$_taf_stage"
        return 0
    fi

    _taf_found=
    _taf_count=0
    for _taf_candidate in "$_taf_stage"/*; do
        [ -d "$_taf_candidate" ] || continue
        if taffish_stage_has_bin_layout "$_taf_candidate"; then
            _taf_found=$_taf_candidate
            _taf_count=$(( _taf_count + 1 ))
            continue
        fi
        if taffish_stage_has_target_layout "$_taf_candidate"; then
            _taf_found=$_taf_candidate
            _taf_count=$(( _taf_count + 1 ))
        fi
    done

    if [ "$_taf_count" -eq 1 ]; then
        printf '%s\n' "$_taf_found"
        return 0
    fi

    taffish_die "can't locate staged TAFFISH layout under $_taf_stage"
}

taffish_validate_stage() {
    _taf_root=$1
    if taffish_stage_has_bin_layout "$_taf_root"; then
        :
    elif taffish_stage_has_target_layout "$_taf_root"; then
        :
    else
        if taffish_should_install_mcp; then
            taffish_die "stage is missing binaries. Expected either bin/{taf,taffish,taffish-mcp} or target/<name>-<os>-<arch>-<version>."
        else
            taffish_die "stage is missing binaries. Expected either bin/{taf,taffish} or target/<name>-<os>-<arch>-<version>."
        fi
    fi

    [ -d "$_taf_root/completion" ] || taffish_warn "stage has no completion/ directory"
    [ -d "$_taf_root/vim-highlight" ] || taffish_warn "stage has no vim-highlight/ directory"
}

taffish_post_install() {
    TAFFISH_POST_DOCTOR_STATUS=skipped
    TAFFISH_POST_CONFIG_STATUS=skipped
    TAFFISH_POST_UPDATE_STATUS=skipped
    if [ "$TAFFISH_INSTALL_NO_DOCTOR" != "1" ]; then
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            if TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
               TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" doctor --init --system; then
                TAFFISH_POST_DOCTOR_STATUS=ok
            else
                TAFFISH_POST_DOCTOR_STATUS=warning
                taffish_warn "taf doctor --init --system failed"
            fi
        else
            if TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" doctor --init --user; then
                TAFFISH_POST_DOCTOR_STATUS=ok
            else
                TAFFISH_POST_DOCTOR_STATUS=warning
                taffish_warn "taf doctor --init --user failed"
            fi
        fi
    fi

    if [ -n "$TAFFISH_INSTALL_CONFIG_PROFILE" ]; then
        _taf_config_force_arg=
        if [ "$TAFFISH_INSTALL_CONFIG_FORCE" = "1" ]; then
            _taf_config_force_arg=--force
        fi
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            # shellcheck disable=SC2086
            if TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
               TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" config init --system "--$TAFFISH_INSTALL_CONFIG_PROFILE" $_taf_config_force_arg; then
                TAFFISH_POST_CONFIG_STATUS=ok
            else
                TAFFISH_POST_CONFIG_STATUS=warning
                taffish_warn "taf config init --system --$TAFFISH_INSTALL_CONFIG_PROFILE failed"
            fi
        else
            # shellcheck disable=SC2086
            if TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" config init --user "--$TAFFISH_INSTALL_CONFIG_PROFILE" $_taf_config_force_arg; then
                TAFFISH_POST_CONFIG_STATUS=ok
            else
                TAFFISH_POST_CONFIG_STATUS=warning
                taffish_warn "taf config init --user --$TAFFISH_INSTALL_CONFIG_PROFILE failed"
            fi
        fi
    fi

    if [ "$TAFFISH_INSTALL_NO_UPDATE" != "1" ]; then
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            if TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
               TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" update --system; then
                TAFFISH_POST_UPDATE_STATUS=ok
            else
                TAFFISH_POST_UPDATE_STATUS=warning
                taffish_warn "taf update --system failed; installation itself is complete"
            fi
        else
            if TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" update --user; then
                TAFFISH_POST_UPDATE_STATUS=ok
            else
                TAFFISH_POST_UPDATE_STATUS=warning
                taffish_warn "taf update --user failed; installation itself is complete"
            fi
        fi
    fi
}

taffish_print_post_install_notes() {
    taffish_info "installed binaries:"
    printf '  %s\n' "$TAFFISH_INSTALL_BIN_DIR/taf"
    printf '  %s\n' "$TAFFISH_INSTALL_BIN_DIR/taffish"
    if taffish_should_install_mcp; then
        printf '  %s\n' "$TAFFISH_INSTALL_BIN_DIR/taffish-mcp"
    fi
    taffish_info "TAFFISH home:"
    printf '  %s\n' "$TAFFISH_INSTALL_HOME"
    taffish_info "verification: $TAFFISH_INSTALL_VERIFICATION_LEVEL"
    taffish_info "core binaries: $TAFFISH_INSTALL_BINARY_ACTION"
    taffish_info "SIF cache policy: $TAFFISH_INSTALL_EFFECTIVE_SIF_POLICY"
    taffish_info "install receipt: $TAFFISH_INSTALL_RECEIPT_PATH"
    taffish_info "post-install: doctor=$TAFFISH_POST_DOCTOR_STATUS config=$TAFFISH_POST_CONFIG_STATUS update=$TAFFISH_POST_UPDATE_STATUS"

    case ":${PATH:-}:" in
        *":$TAFFISH_INSTALL_BIN_DIR:"*) ;;
        *)
            taffish_warn "$TAFFISH_INSTALL_BIN_DIR is not in PATH"
            printf '%s\n' "  add this to your shell profile:"
            printf '%s\n' "  export PATH=\"$TAFFISH_INSTALL_BIN_DIR:\$PATH\""
            ;;
    esac

    taffish_info "completion files installed under:"
    printf '  %s\n' "$TAFFISH_INSTALL_HOME/share/completions"
    taffish_info "vim files installed under:"
    printf '  %s\n' "$TAFFISH_INSTALL_HOME/share/vim"
}

taffish_install_from_stage() {
    _taf_stage_input=$1
    TAFFISH_INSTALL_SOURCE_KIND=bundle
    taffish_resolve_install_paths
    _taf_root=$(taffish_stage_root "$_taf_stage_input")
    taffish_validate_stage "$_taf_root"

    taffish_info "install scope: $TAFFISH_INSTALL_SCOPE"
    taffish_info "bin dir      : $TAFFISH_INSTALL_BIN_DIR"
    taffish_info "TAFFISH home : $TAFFISH_INSTALL_HOME"

    if taffish_stage_has_bin_layout "$_taf_root"; then
        _taf_install_src_taf=$_taf_root/bin/taf
        _taf_install_src_taffish=$_taf_root/bin/taffish
        _taf_install_asset_taf=taf
        _taf_install_asset_taffish=taffish
        if taffish_should_install_mcp; then
            _taf_install_src_taffish_mcp=$_taf_root/bin/taffish-mcp
            _taf_install_asset_taffish_mcp=taffish-mcp
        fi
    else
        _taf_install_src_taf=$(taffish_select_target_binary "$_taf_root/target" taf) || \
            taffish_die "can't select host taf binary from $_taf_root/target"
        _taf_install_src_taffish=$(taffish_select_target_binary "$_taf_root/target" taffish) || \
            taffish_die "can't select host taffish binary from $_taf_root/target"
        _taf_install_asset_taf=${_taf_install_src_taf##*/}
        _taf_install_asset_taffish=${_taf_install_src_taffish##*/}
        if taffish_should_install_mcp; then
            _taf_install_src_taffish_mcp=$(taffish_select_target_binary "$_taf_root/target" taffish-mcp) || \
                taffish_die "can't select host taffish-mcp binary from $_taf_root/target"
            _taf_install_asset_taffish_mcp=${_taf_install_src_taffish_mcp##*/}
        fi
    fi

    TAFFISH_INSTALL_SELECTED_ASSET_TAF=$_taf_install_asset_taf
    TAFFISH_INSTALL_SELECTED_ASSET_TAFFISH=$_taf_install_asset_taffish
    if taffish_should_install_mcp; then
        TAFFISH_INSTALL_SELECTED_ASSET_MCP=$_taf_install_asset_taffish_mcp
    else
        TAFFISH_INSTALL_SELECTED_ASSET_MCP=
    fi

    taffish_prepare_stage_verification "$_taf_root"
    if taffish_should_install_mcp; then
        taffish_verify_payload \
            "$TAFFISH_VERIFY_MANIFEST" "$TAFFISH_VERIFY_SIGNATURE" "$TAFFISH_VERIFY_KEY" \
            "$_taf_install_asset_taf" "$_taf_install_src_taf" \
            "$_taf_install_asset_taffish" "$_taf_install_src_taffish" \
            "$_taf_install_asset_taffish_mcp" "$_taf_install_src_taffish_mcp"
    else
        taffish_verify_payload \
            "$TAFFISH_VERIFY_MANIFEST" "$TAFFISH_VERIFY_SIGNATURE" "$TAFFISH_VERIFY_KEY" \
            "$_taf_install_asset_taf" "$_taf_install_src_taf" \
            "$_taf_install_asset_taffish" "$_taf_install_src_taffish"
    fi

    taffish_prepare_install_home
    taffish_acquire_install_lock
    taffish_make_required_dirs
    if taffish_should_install_mcp; then
        taffish_install_binaries_transactionally \
            "$_taf_install_src_taf" "$_taf_install_src_taffish" \
            "$_taf_install_src_taffish_mcp"
    else
        taffish_install_binaries_transactionally \
            "$_taf_install_src_taf" "$_taf_install_src_taffish"
    fi

    taffish_write_install_receipt
    taffish_finalize_binary_transaction

    taffish_copy_tree_files "$_taf_root/completion/bash" "$TAFFISH_INSTALL_HOME/share/completions/bash"
    taffish_copy_tree_files "$_taf_root/completion/zsh" "$TAFFISH_INSTALL_HOME/share/completions/zsh"
    taffish_copy_tree_files "$_taf_root/completion/fish" "$TAFFISH_INSTALL_HOME/share/completions/fish"
    taffish_copy_tree_files "$_taf_root/vim-highlight/syntax" "$TAFFISH_INSTALL_HOME/share/vim/syntax"
    taffish_copy_tree_files "$_taf_root/vim-highlight/ftdetect" "$TAFFISH_INSTALL_HOME/share/vim/ftdetect"

    taffish_release_install_lock
    taffish_post_install
    taffish_print_post_install_notes
}

taffish_raw_base_url() {
    if [ -n "$TAFFISH_INSTALL_RAW_BASE_URL" ]; then
        taffish_strip_trailing_slash "$TAFFISH_INSTALL_RAW_BASE_URL"
        return 0
    fi

    _taf_tag=$(taffish_version_tag)
    case "$TAFFISH_INSTALL_PROVIDER" in
        github)
            printf '%s\n' "https://raw.githubusercontent.com/$REPO/$_taf_tag"
            ;;
        gitee)
            printf '%s\n' "https://gitee.com/$REPO/raw/$_taf_tag"
            ;;
        *)
            taffish_die "unsupported provider: $TAFFISH_INSTALL_PROVIDER"
            ;;
    esac
}

taffish_raw_file_url() {
    _taf_path=$1
    printf '%s/%s\n' "$(taffish_raw_base_url)" "$_taf_path"
}

taffish_tag_archive_url() {
    _taf_tag=$(taffish_version_tag)
    case "$TAFFISH_INSTALL_PROVIDER" in
        github)
            printf '%s\n' "https://github.com/$REPO/archive/refs/tags/$_taf_tag.tar.gz"
            ;;
        gitee)
            printf '%s\n' "https://gitee.com/$REPO/repository/archive/$_taf_tag.tar.gz"
            ;;
        *)
            taffish_die "unsupported provider: $TAFFISH_INSTALL_PROVIDER"
            ;;
    esac
}

taffish_try_download_raw_binary() {
    _taf_name=$1
    _taf_out=$2
    _taf_os=$(taffish_detect_target_os)
    _taf_arch=$(taffish_detect_target_arch)
    _taf_version_plain=$(taffish_version_plain)

    for _taf_os_alias in $(taffish_target_os_aliases "$_taf_os"); do
        for _taf_arch_alias in $(taffish_target_arch_aliases "$_taf_arch"); do
            _taf_asset="$_taf_name-$_taf_os_alias-$_taf_arch_alias-$_taf_version_plain"
            _taf_url=$(taffish_raw_file_url "target/$_taf_asset")
            taffish_info "trying $_taf_url"
            if taffish_try_download_file "$_taf_url" "$_taf_out"; then
                TAFFISH_DOWNLOADED_ASSET=$_taf_asset
                return 0
            fi

            _taf_asset="$_taf_name-$_taf_os_alias-$_taf_arch_alias"
            _taf_url=$(taffish_raw_file_url "target/$_taf_asset")
            taffish_info "trying $_taf_url"
            if taffish_try_download_file "$_taf_url" "$_taf_out"; then
                TAFFISH_DOWNLOADED_ASSET=$_taf_asset
                return 0
            fi
        done
    done

    return 1
}

taffish_install_raw_optional_file() {
    _taf_path=$1
    _taf_dst=$2
    _taf_tmp="$TMPDIR_INSTALL/raw-file"
    _taf_url=$(taffish_raw_file_url "$_taf_path")
    if taffish_try_download_file "$_taf_url" "$_taf_tmp"; then
        taffish_install_file "$_taf_tmp" "$_taf_dst" 0644
        return 0
    fi
    taffish_warn "optional file not available: $_taf_url"
    return 0
}

taffish_install_raw_share_files() {
    taffish_install_raw_optional_file \
        "completion/bash/taf" \
        "$TAFFISH_INSTALL_HOME/share/completions/bash/taf"
    taffish_install_raw_optional_file \
        "completion/bash/taffish" \
        "$TAFFISH_INSTALL_HOME/share/completions/bash/taffish"
    taffish_install_raw_optional_file \
        "completion/zsh/_taf" \
        "$TAFFISH_INSTALL_HOME/share/completions/zsh/_taf"
    taffish_install_raw_optional_file \
        "completion/zsh/_taffish" \
        "$TAFFISH_INSTALL_HOME/share/completions/zsh/_taffish"
    taffish_install_raw_optional_file \
        "completion/fish/taf.fish" \
        "$TAFFISH_INSTALL_HOME/share/completions/fish/taf.fish"
    taffish_install_raw_optional_file \
        "completion/fish/taffish.fish" \
        "$TAFFISH_INSTALL_HOME/share/completions/fish/taffish.fish"
    taffish_install_raw_optional_file \
        "vim-highlight/syntax/taf.vim" \
        "$TAFFISH_INSTALL_HOME/share/vim/syntax/taf.vim"
    taffish_install_raw_optional_file \
        "vim-highlight/syntax/old-taf.vim" \
        "$TAFFISH_INSTALL_HOME/share/vim/syntax/old-taf.vim"
    taffish_install_raw_optional_file \
        "vim-highlight/ftdetect/taf.vim" \
        "$TAFFISH_INSTALL_HOME/share/vim/ftdetect/taf.vim"
}

taffish_first_subdir() {
    _taf_parent=$1
    for _taf_candidate in "$_taf_parent"/*; do
        [ -d "$_taf_candidate" ] || continue
        printf '%s\n' "$_taf_candidate"
        return 0
    done
    return 1
}

taffish_install_from_remote_raw() {
    TAFFISH_INSTALL_SOURCE_KIND=raw
    taffish_resolve_install_paths
    taffish_info "install scope: $TAFFISH_INSTALL_SCOPE"
    taffish_info "bin dir      : $TAFFISH_INSTALL_BIN_DIR"
    taffish_info "TAFFISH home : $TAFFISH_INSTALL_HOME"
    taffish_info "provider     : $TAFFISH_INSTALL_PROVIDER"
    taffish_info "source tag   : $(taffish_version_tag)"

    _taf_bin_dir="$TMPDIR_INSTALL/bin"
    mkdir -p "$_taf_bin_dir" || taffish_die "failed to create temp bin dir"

    _taf_taf_tmp="$_taf_bin_dir/taf"
    _taf_taffish_tmp="$_taf_bin_dir/taffish"
    _taf_taffish_mcp_tmp="$_taf_bin_dir/taffish-mcp"

    if [ -n "$TAF_URL" ]; then
        taffish_download_file "$TAF_URL" "$_taf_taf_tmp"
        _taf_taf_asset=$(taffish_url_basename "$TAF_URL")
    else
        taffish_try_download_raw_binary "taf" "$_taf_taf_tmp" || \
            taffish_die "can't find matching taf binary under $(taffish_raw_file_url target)"
        _taf_taf_asset=$TAFFISH_DOWNLOADED_ASSET
    fi

    if [ -n "$TAFFISH_URL" ]; then
        taffish_download_file "$TAFFISH_URL" "$_taf_taffish_tmp"
        _taf_taffish_asset=$(taffish_url_basename "$TAFFISH_URL")
    else
        taffish_try_download_raw_binary "taffish" "$_taf_taffish_tmp" || \
            taffish_die "can't find matching taffish binary under $(taffish_raw_file_url target)"
        _taf_taffish_asset=$TAFFISH_DOWNLOADED_ASSET
    fi

    if taffish_should_install_mcp; then
        if [ -n "$TAFFISH_MCP_URL" ]; then
            taffish_download_file "$TAFFISH_MCP_URL" "$_taf_taffish_mcp_tmp"
            _taf_taffish_mcp_asset=$(taffish_url_basename "$TAFFISH_MCP_URL")
        else
            taffish_try_download_raw_binary "taffish-mcp" "$_taf_taffish_mcp_tmp" || \
                taffish_die "can't find matching taffish-mcp binary under $(taffish_raw_file_url target)"
            _taf_taffish_mcp_asset=$TAFFISH_DOWNLOADED_ASSET
        fi
    fi

    TAFFISH_INSTALL_SELECTED_ASSET_TAF=$_taf_taf_asset
    TAFFISH_INSTALL_SELECTED_ASSET_TAFFISH=$_taf_taffish_asset
    if taffish_should_install_mcp; then
        TAFFISH_INSTALL_SELECTED_ASSET_MCP=$_taf_taffish_mcp_asset
    else
        TAFFISH_INSTALL_SELECTED_ASSET_MCP=
    fi

    taffish_prepare_remote_verification
    if taffish_should_install_mcp; then
        taffish_verify_payload \
            "$TAFFISH_VERIFY_MANIFEST" "$TAFFISH_VERIFY_SIGNATURE" "$TAFFISH_VERIFY_KEY" \
            "$_taf_taf_asset" "$_taf_taf_tmp" \
            "$_taf_taffish_asset" "$_taf_taffish_tmp" \
            "$_taf_taffish_mcp_asset" "$_taf_taffish_mcp_tmp"
    else
        taffish_verify_payload \
            "$TAFFISH_VERIFY_MANIFEST" "$TAFFISH_VERIFY_SIGNATURE" "$TAFFISH_VERIFY_KEY" \
            "$_taf_taf_asset" "$_taf_taf_tmp" \
            "$_taf_taffish_asset" "$_taf_taffish_tmp"
    fi

    taffish_prepare_install_home
    taffish_acquire_install_lock
    taffish_make_required_dirs
    if taffish_should_install_mcp; then
        taffish_install_binaries_transactionally \
            "$_taf_taf_tmp" "$_taf_taffish_tmp" "$_taf_taffish_mcp_tmp"
    else
        taffish_install_binaries_transactionally "$_taf_taf_tmp" "$_taf_taffish_tmp"
    fi

    taffish_write_install_receipt
    taffish_finalize_binary_transaction

    if [ -n "$SHARE_URL" ]; then
        _taf_share_archive="$TMPDIR_INSTALL/share.tar.gz"
        taffish_download_file "$SHARE_URL" "$_taf_share_archive"

        _taf_share_extract="$TMPDIR_INSTALL/share-extract"
        mkdir -p "$_taf_share_extract" || taffish_die "failed to create temp share dir"
        taffish_validate_archive "$_taf_share_archive"
        tar -xzf "$_taf_share_archive" -C "$_taf_share_extract" || \
            taffish_die "failed to extract share archive: $SHARE_URL"

        _taf_share_root=$(taffish_first_subdir "$_taf_share_extract" || true)
        if [ -z "$_taf_share_root" ]; then
            _taf_share_root=$_taf_share_extract
        fi

        taffish_copy_tree_files "$_taf_share_root/completion/bash" "$TAFFISH_INSTALL_HOME/share/completions/bash"
        taffish_copy_tree_files "$_taf_share_root/completion/zsh" "$TAFFISH_INSTALL_HOME/share/completions/zsh"
        taffish_copy_tree_files "$_taf_share_root/completion/fish" "$TAFFISH_INSTALL_HOME/share/completions/fish"
        taffish_copy_tree_files "$_taf_share_root/vim-highlight/syntax" "$TAFFISH_INSTALL_HOME/share/vim/syntax"
        taffish_copy_tree_files "$_taf_share_root/vim-highlight/ftdetect" "$TAFFISH_INSTALL_HOME/share/vim/ftdetect"
    else
        taffish_install_raw_share_files
    fi

    taffish_release_install_lock
    taffish_post_install
    taffish_print_post_install_notes
}

usage() {
    cat <<'EOF'
Usage:
  install-taffish.gitee.sh [OPTIONS]

Install TAFFISH from raw files under a fixed git tag.

Default mode (no --archive/--url):
  - download taf/taffish/taffish-mcp binaries from target/ under tag v<version>
  - download completion/vim files from the same tag

Options:
  --user                    Install for current user [default]
  --system                  Install system-wide
  --prefix DIR              Set software prefix; implies bin=DIR/bin,
                            home=DIR/share/taffish unless overridden
  --bin-dir DIR             Override executable install directory
  --taffish-home DIR        Override TAFFISH runtime home
  --repo OWNER/REPO         Gitee repository [taffish-org/taffish]
  --version VERSION         Release version [0.11.0]
  --provider PROVIDER       Raw provider: github or gitee [gitee]
  --raw-base-url URL        Override raw base URL. It should point at a tag,
                            for example .../raw/v0.11.0
  --os OS                   Override target OS (darwin|macos|linux)
  --arch ARCH               Override target arch (amd64|x86_64|arm64|aarch64)
  --taf-url URL             Override taf binary URL
  --taffish-url URL         Override taffish binary URL
  --taffish-mcp-url URL     Override taffish-mcp binary URL
  --share-url URL           Override completion/vim source with tar.gz archive
  --url URL                 Download full bundle tarball from explicit URL
  --archive FILE            Install from local tar.gz archive
  --verify MODE             Payload verification: auto, sha256, gpg, or none
                            [auto; official raw installs require SHA256]
  --checksum-file FILE      Use a local SHA256SUMS manifest
  --checksum-url URL        Download SHA256SUMS from an explicit URL
  --signature-file FILE     Use a local detached checksum signature
  --signature-url URL       Download checksum signature from an explicit URL
  --release-key-file FILE   Use a local release public key
  --release-key-url URL     Download release public key from an explicit URL
  --retry COUNT             Retry failed downloads COUNT times [3]
  --connect-timeout SEC     Download connection timeout in seconds [15]
  --config-profile PROFILE  Initialize taf config profile after install:
                            github, china, or none [china]
  --force-config            Replace existing config during config init
  --force                   Replace an unrecognized file at a core command path
  --sif-cache-policy POLICY Apptainer SIF cache policy:
                            auto, private, admin, or shared [auto]
  --shared-sif-cache        Alias for --sif-cache-policy shared
  --dry-run                 Print the resolved install plan without network or writes
  --no-update               Do not run taf update after install
  --no-doctor               Do not run taf doctor --init after install
  -h, --help                Show this help

Language after installation:
  English (en) and Chinese (zh) are built in; no language download is needed.
  With no saved preference, auto follows the host locale with English fallback.
  Run taf config language to inspect languages, or taf config language zh to switch.
  GitHub/Gitee source selection does not select the CLI language.
  The standalone installer's own messages remain in English.

Release tarball layout:
  target/taf-<os>-<arch>-<version> (or bin/taf for legacy)
  target/taffish-<os>-<arch>-<version> (or bin/taffish for legacy)
  target/taffish-mcp-<os>-<arch>-<version> (or bin/taffish-mcp for legacy)
  completion/
  vim-highlight/

Default GitHub raw URLs:
  https://raw.githubusercontent.com/<repo>/v<version>/target/taf-<os>-<arch>-<version>
  https://raw.githubusercontent.com/<repo>/v<version>/target/taffish-<os>-<arch>-<version>
  https://raw.githubusercontent.com/<repo>/v<version>/target/taffish-mcp-<os>-<arch>-<version>

Default Gitee raw URLs:
  https://gitee.com/<repo>/raw/v<version>/target/taf-<os>-<arch>-<version>
  https://gitee.com/<repo>/raw/v<version>/target/taffish-<os>-<arch>-<version>
  https://gitee.com/<repo>/raw/v<version>/target/taffish-mcp-<os>-<arch>-<version>

Bundle mode (--archive or --url):
  Stage must include target/ with binaries and optional completion/vim files.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --user)
            TAFFISH_INSTALL_SCOPE=user
            shift
            ;;
        --system)
            TAFFISH_INSTALL_SCOPE=system
            shift
            ;;
        --prefix)
            [ "$#" -ge 2 ] || taffish_die "--prefix requires a value"
            TAFFISH_INSTALL_PREFIX=$2
            shift 2
            ;;
        --bin-dir)
            [ "$#" -ge 2 ] || taffish_die "--bin-dir requires a value"
            TAFFISH_INSTALL_BIN_DIR=$2
            shift 2
            ;;
        --taffish-home)
            [ "$#" -ge 2 ] || taffish_die "--taffish-home requires a value"
            TAFFISH_INSTALL_HOME=$2
            shift 2
            ;;
        --repo)
            [ "$#" -ge 2 ] || taffish_die "--repo requires a value"
            REPO=$2
            shift 2
            ;;
        --version)
            [ "$#" -ge 2 ] || taffish_die "--version requires a value"
            VERSION=$2
            shift 2
            ;;
        --provider)
            [ "$#" -ge 2 ] || taffish_die "--provider requires a value"
            TAFFISH_INSTALL_PROVIDER=$2
            shift 2
            ;;
        --raw-base-url)
            [ "$#" -ge 2 ] || taffish_die "--raw-base-url requires a value"
            TAFFISH_INSTALL_RAW_BASE_URL=$2
            shift 2
            ;;
        --os)
            [ "$#" -ge 2 ] || taffish_die "--os requires a value"
            TARGET_OS_OVERRIDE=$2
            shift 2
            ;;
        --arch)
            [ "$#" -ge 2 ] || taffish_die "--arch requires a value"
            TARGET_ARCH_OVERRIDE=$2
            shift 2
            ;;
        --taf-url)
            [ "$#" -ge 2 ] || taffish_die "--taf-url requires a value"
            TAF_URL=$2
            shift 2
            ;;
        --taffish-url)
            [ "$#" -ge 2 ] || taffish_die "--taffish-url requires a value"
            TAFFISH_URL=$2
            shift 2
            ;;
        --taffish-mcp-url)
            [ "$#" -ge 2 ] || taffish_die "--taffish-mcp-url requires a value"
            TAFFISH_MCP_URL=$2
            shift 2
            ;;
        --share-url)
            [ "$#" -ge 2 ] || taffish_die "--share-url requires a value"
            SHARE_URL=$2
            shift 2
            ;;
        --url)
            [ "$#" -ge 2 ] || taffish_die "--url requires a value"
            URL=$2
            shift 2
            ;;
        --archive)
            [ "$#" -ge 2 ] || taffish_die "--archive requires a value"
            ARCHIVE=$2
            shift 2
            ;;
        --verify)
            [ "$#" -ge 2 ] || taffish_die "--verify requires a value"
            TAFFISH_INSTALL_VERIFY=$2
            shift 2
            ;;
        --checksum-file)
            [ "$#" -ge 2 ] || taffish_die "--checksum-file requires a value"
            CHECKSUM_FILE=$2
            shift 2
            ;;
        --checksum-url)
            [ "$#" -ge 2 ] || taffish_die "--checksum-url requires a value"
            CHECKSUM_URL=$2
            shift 2
            ;;
        --signature-file)
            [ "$#" -ge 2 ] || taffish_die "--signature-file requires a value"
            SIGNATURE_FILE=$2
            shift 2
            ;;
        --signature-url)
            [ "$#" -ge 2 ] || taffish_die "--signature-url requires a value"
            SIGNATURE_URL=$2
            shift 2
            ;;
        --release-key-file)
            [ "$#" -ge 2 ] || taffish_die "--release-key-file requires a value"
            RELEASE_KEY_FILE=$2
            shift 2
            ;;
        --release-key-url)
            [ "$#" -ge 2 ] || taffish_die "--release-key-url requires a value"
            RELEASE_KEY_URL=$2
            shift 2
            ;;
        --retry)
            [ "$#" -ge 2 ] || taffish_die "--retry requires a value"
            TAFFISH_INSTALL_RETRY=$2
            shift 2
            ;;
        --connect-timeout)
            [ "$#" -ge 2 ] || taffish_die "--connect-timeout requires a value"
            TAFFISH_INSTALL_CONNECT_TIMEOUT=$2
            shift 2
            ;;
        --config-profile)
            [ "$#" -ge 2 ] || taffish_die "--config-profile requires a value"
            TAFFISH_INSTALL_CONFIG_PROFILE=$2
            shift 2
            ;;
        --force-config)
            TAFFISH_INSTALL_CONFIG_FORCE=1
            shift
            ;;
        --force)
            TAFFISH_INSTALL_FORCE=1
            shift
            ;;
        --sif-cache-policy)
            [ "$#" -ge 2 ] || taffish_die "--sif-cache-policy requires a value"
            TAFFISH_INSTALL_SIF_CACHE_POLICY=$2
            shift 2
            ;;
        --shared-sif-cache)
            TAFFISH_INSTALL_SIF_CACHE_POLICY=shared
            shift
            ;;
        --dry-run)
            TAFFISH_INSTALL_DRY_RUN=1
            shift
            ;;
        --no-update)
            TAFFISH_INSTALL_NO_UPDATE=1
            shift
            ;;
        --no-doctor)
            TAFFISH_INSTALL_NO_DOCTOR=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            taffish_die "unknown option: $1"
            ;;
    esac
done

TAFFISH_INSTALL_PROVIDER=$(taffish_normalize_provider "$TAFFISH_INSTALL_PROVIDER")
TAFFISH_INSTALL_CONFIG_PROFILE=$(taffish_normalize_config_profile "$TAFFISH_INSTALL_CONFIG_PROFILE")
TAFFISH_INSTALL_SIF_CACHE_POLICY=$(taffish_normalize_sif_cache_policy "$TAFFISH_INSTALL_SIF_CACHE_POLICY")
TAFFISH_INSTALL_VERIFY=$(taffish_normalize_verify_mode "$TAFFISH_INSTALL_VERIFY")
TAFFISH_INSTALL_RETRY=$(taffish_normalize_nonnegative_integer "--retry" "$TAFFISH_INSTALL_RETRY")
TAFFISH_INSTALL_CONNECT_TIMEOUT=$(taffish_normalize_positive_integer "--connect-timeout" "$TAFFISH_INSTALL_CONNECT_TIMEOUT")
[ -n "$TAFFISH_INSTALL_RAW_BASE_URL" ] && TAFFISH_INSTALL_RAW_BASE_URL=$(taffish_strip_trailing_slash "$TAFFISH_INSTALL_RAW_BASE_URL")
[ -n "$TARGET_OS_OVERRIDE" ] && TARGET_OS_OVERRIDE=$(taffish_normalize_target_os "$TARGET_OS_OVERRIDE")
[ -n "$TARGET_ARCH_OVERRIDE" ] && TARGET_ARCH_OVERRIDE=$(taffish_normalize_target_arch "$TARGET_ARCH_OVERRIDE")

[ -n "$ARCHIVE" ] && [ -n "$URL" ] && taffish_die "--archive and --url can't be used together"
[ -n "$CHECKSUM_FILE" ] && [ -n "$CHECKSUM_URL" ] && \
    taffish_die "--checksum-file and --checksum-url can't be used together"
[ -n "$SIGNATURE_FILE" ] && [ -n "$SIGNATURE_URL" ] && \
    taffish_die "--signature-file and --signature-url can't be used together"
[ -n "$RELEASE_KEY_FILE" ] && [ -n "$RELEASE_KEY_URL" ] && \
    taffish_die "--release-key-file and --release-key-url can't be used together"

taffish_resolve_install_paths
taffish_preflight_scope

if [ "$TAFFISH_INSTALL_DRY_RUN" = "1" ]; then
    taffish_print_dry_run
    exit 0
fi

taffish_need_command tar
taffish_need_command mktemp

TMPDIR_INSTALL=$(mktemp -d "${TMPDIR:-/tmp}/taffish-install.XXXXXX") || taffish_die "failed to create temp directory"
cleanup() {
    taffish_rollback_binary_transaction
    taffish_release_install_lock
    [ -z "$TAFFISH_INSTALL_RECEIPT_TMP" ] || \
        rm -f "$TAFFISH_INSTALL_RECEIPT_TMP"
    rm -rf "$TMPDIR_INSTALL"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

if [ -n "$ARCHIVE" ] || [ -n "$URL" ]; then
    if [ -n "$SHARE_URL" ]; then
        taffish_warn "--share-url is ignored in bundle mode (--archive/--url)."
    fi

    if [ -n "$ARCHIVE" ]; then
        [ -f "$ARCHIVE" ] || taffish_die "archive does not exist: $ARCHIVE"
        TARBALL=$TMPDIR_INSTALL/taffish-local.tar.gz
        cp "$ARCHIVE" "$TARBALL" || \
            taffish_die "failed to snapshot local archive: $ARCHIVE"
    else
        TARBALL=$TMPDIR_INSTALL/taffish.tar.gz
        taffish_download_file "$URL" "$TARBALL"
    fi

    STAGE_PARENT=$TMPDIR_INSTALL/stage
    mkdir -p "$STAGE_PARENT" || taffish_die "failed to create stage directory"
    taffish_validate_archive "$TARBALL"
    tar -xzf "$TARBALL" -C "$STAGE_PARENT" || taffish_die "failed to unpack tarball"
    taffish_install_from_stage "$STAGE_PARENT"
else
    taffish_install_from_remote_raw
fi
