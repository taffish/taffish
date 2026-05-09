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

REPO=taffish-org/taffish
VERSION=0.3.0
ARCHIVE=
URL=
SHARE_URL=
TAF_URL=
TAFFISH_URL=
TARGET_OS_OVERRIDE=
TARGET_ARCH_OVERRIDE=

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
        if curl -fsSL "$_taf_url" -o "$_taf_out"; then
            return 0
        fi
    elif taffish_command_exists wget; then
        if wget -q -O "$_taf_out" "$_taf_url"; then
            return 0
        fi
    else
        taffish_die "curl or wget is required for download"
    fi
    rm -f "$_taf_out"
    return 1
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
bin
cache
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

taffish_make_required_dirs() {
    mkdir -p "$TAFFISH_INSTALL_BIN_DIR" || taffish_die "failed to create bin dir: $TAFFISH_INSTALL_BIN_DIR"
    mkdir -p "$TAFFISH_INSTALL_HOME" || taffish_die "failed to create TAFFISH home: $TAFFISH_INSTALL_HOME"
    taffish_required_home_dirs | while IFS= read -r _taf_dir; do
        [ -n "$_taf_dir" ] || continue
        mkdir -p "$TAFFISH_INSTALL_HOME/$_taf_dir" || exit 1
    done
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

taffish_copy_tree_files() {
    _taf_src_dir=$1
    _taf_dst_dir=$2

    [ -d "$_taf_src_dir" ] || return 0
    find "$_taf_src_dir" -type f | while IFS= read -r _taf_file; do
        _taf_rel=${_taf_file#"$_taf_src_dir"/}
        taffish_install_file "$_taf_file" "$_taf_dst_dir/$_taf_rel" 0644
    done
}

taffish_stage_has_target_layout() {
    _taf_root=$1
    [ -d "$_taf_root/target" ] || return 1
    taffish_select_target_binary "$_taf_root/target" taf >/dev/null 2>&1 || return 1
    taffish_select_target_binary "$_taf_root/target" taffish >/dev/null 2>&1 || return 1
    return 0
}

taffish_stage_root() {
    _taf_stage=$1
    [ -d "$_taf_stage" ] || taffish_die "stage directory does not exist: $_taf_stage"

    if [ -f "$_taf_stage/bin/taf" ] && [ -f "$_taf_stage/bin/taffish" ]; then
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
        if [ -f "$_taf_candidate/bin/taf" ] && [ -f "$_taf_candidate/bin/taffish" ]; then
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
    if [ -f "$_taf_root/bin/taf" ] && [ -f "$_taf_root/bin/taffish" ]; then
        :
    elif taffish_stage_has_target_layout "$_taf_root"; then
        :
    else
        taffish_die "stage is missing binaries. Expected either bin/{taf,taffish} or target/taf-<os>-<arch>-<version>."
    fi

    [ -d "$_taf_root/completion" ] || taffish_warn "stage has no completion/ directory"
    [ -d "$_taf_root/vim-highlight" ] || taffish_warn "stage has no vim-highlight/ directory"
}

taffish_post_install() {
    if [ "$TAFFISH_INSTALL_NO_DOCTOR" != "1" ]; then
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
            TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" doctor --init --system || \
                taffish_warn "taf doctor --init --system failed"
        else
            TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" doctor --init --user || \
                taffish_warn "taf doctor --init --user failed"
        fi
    fi

    if [ -n "$TAFFISH_INSTALL_CONFIG_PROFILE" ]; then
        _taf_config_force_arg=
        if [ "$TAFFISH_INSTALL_CONFIG_FORCE" = "1" ]; then
            _taf_config_force_arg=--force
        fi
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            # shellcheck disable=SC2086
            TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
            TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" config init --system "--$TAFFISH_INSTALL_CONFIG_PROFILE" $_taf_config_force_arg || \
                taffish_warn "taf config init --system --$TAFFISH_INSTALL_CONFIG_PROFILE failed"
        else
            # shellcheck disable=SC2086
            TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" config init --user "--$TAFFISH_INSTALL_CONFIG_PROFILE" $_taf_config_force_arg || \
                taffish_warn "taf config init --user --$TAFFISH_INSTALL_CONFIG_PROFILE failed"
        fi
    fi

    if [ "$TAFFISH_INSTALL_NO_UPDATE" != "1" ]; then
        if [ "$TAFFISH_INSTALL_SCOPE" = "system" ]; then
            TAFFISH_SYSTEM_HOME=$TAFFISH_INSTALL_HOME \
            TAFFISH_SYSTEM_BIN_DIR=$TAFFISH_INSTALL_BIN_DIR \
                "$TAFFISH_INSTALL_BIN_DIR/taf" update --system || \
                taffish_warn "taf update --system failed; installation itself is complete"
        else
            TAFFISH_USER_HOME=$TAFFISH_INSTALL_HOME \
                "$TAFFISH_INSTALL_BIN_DIR/taf" update --user || \
                taffish_warn "taf update --user failed; installation itself is complete"
        fi
    fi
}

taffish_print_post_install_notes() {
    taffish_info "installed binaries:"
    printf '  %s\n' "$TAFFISH_INSTALL_BIN_DIR/taf"
    printf '  %s\n' "$TAFFISH_INSTALL_BIN_DIR/taffish"
    taffish_info "TAFFISH home:"
    printf '  %s\n' "$TAFFISH_INSTALL_HOME"

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
    taffish_resolve_install_paths
    _taf_root=$(taffish_stage_root "$_taf_stage_input")
    taffish_validate_stage "$_taf_root"

    taffish_info "install scope: $TAFFISH_INSTALL_SCOPE"
    taffish_info "bin dir      : $TAFFISH_INSTALL_BIN_DIR"
    taffish_info "TAFFISH home : $TAFFISH_INSTALL_HOME"

    taffish_make_required_dirs

    if [ -f "$_taf_root/bin/taf" ] && [ -f "$_taf_root/bin/taffish" ]; then
        _taf_install_src_taf=$_taf_root/bin/taf
        _taf_install_src_taffish=$_taf_root/bin/taffish
    else
        _taf_install_src_taf=$(taffish_select_target_binary "$_taf_root/target" taf) || \
            taffish_die "can't select host taf binary from $_taf_root/target"
        _taf_install_src_taffish=$(taffish_select_target_binary "$_taf_root/target" taffish) || \
            taffish_die "can't select host taffish binary from $_taf_root/target"
    fi

    taffish_install_file "$_taf_install_src_taf" "$TAFFISH_INSTALL_BIN_DIR/taf" 0755
    taffish_install_file "$_taf_install_src_taffish" "$TAFFISH_INSTALL_BIN_DIR/taffish" 0755

    taffish_copy_tree_files "$_taf_root/completion/bash" "$TAFFISH_INSTALL_HOME/share/completions/bash"
    taffish_copy_tree_files "$_taf_root/completion/zsh" "$TAFFISH_INSTALL_HOME/share/completions/zsh"
    taffish_copy_tree_files "$_taf_root/completion/fish" "$TAFFISH_INSTALL_HOME/share/completions/fish"
    taffish_copy_tree_files "$_taf_root/vim-highlight/syntax" "$TAFFISH_INSTALL_HOME/share/vim/syntax"
    taffish_copy_tree_files "$_taf_root/vim-highlight/ftdetect" "$TAFFISH_INSTALL_HOME/share/vim/ftdetect"

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
                return 0
            fi

            _taf_asset="$_taf_name-$_taf_os_alias-$_taf_arch_alias"
            _taf_url=$(taffish_raw_file_url "target/$_taf_asset")
            taffish_info "trying $_taf_url"
            if taffish_try_download_file "$_taf_url" "$_taf_out"; then
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
    taffish_resolve_install_paths
    taffish_info "install scope: $TAFFISH_INSTALL_SCOPE"
    taffish_info "bin dir      : $TAFFISH_INSTALL_BIN_DIR"
    taffish_info "TAFFISH home : $TAFFISH_INSTALL_HOME"
    taffish_info "provider     : $TAFFISH_INSTALL_PROVIDER"
    taffish_info "source tag   : $(taffish_version_tag)"

    taffish_make_required_dirs

    _taf_bin_dir="$TMPDIR_INSTALL/bin"
    mkdir -p "$_taf_bin_dir" || taffish_die "failed to create temp bin dir"

    _taf_taf_tmp="$_taf_bin_dir/taf"
    _taf_taffish_tmp="$_taf_bin_dir/taffish"

    if [ -n "$TAF_URL" ]; then
        taffish_download_file "$TAF_URL" "$_taf_taf_tmp"
    else
        taffish_try_download_raw_binary "taf" "$_taf_taf_tmp" || \
            taffish_die "can't find matching taf binary under $(taffish_raw_file_url target)"
    fi

    if [ -n "$TAFFISH_URL" ]; then
        taffish_download_file "$TAFFISH_URL" "$_taf_taffish_tmp"
    else
        taffish_try_download_raw_binary "taffish" "$_taf_taffish_tmp" || \
            taffish_die "can't find matching taffish binary under $(taffish_raw_file_url target)"
    fi

    taffish_install_file "$_taf_taf_tmp" "$TAFFISH_INSTALL_BIN_DIR/taf" 0755
    taffish_install_file "$_taf_taffish_tmp" "$TAFFISH_INSTALL_BIN_DIR/taffish" 0755

    if [ -n "$SHARE_URL" ]; then
        _taf_share_archive="$TMPDIR_INSTALL/share.tar.gz"
        taffish_download_file "$SHARE_URL" "$_taf_share_archive"

        _taf_share_extract="$TMPDIR_INSTALL/share-extract"
        mkdir -p "$_taf_share_extract" || taffish_die "failed to create temp share dir"
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

    taffish_post_install
    taffish_print_post_install_notes
}

usage() {
    cat <<'EOF'
Usage:
  install-taffish.gitee.sh [OPTIONS]

Install TAFFISH from raw files under a fixed git tag.

Default mode (no --archive/--url):
  - download taf/taffish binaries from target/ under tag v<version>
  - download completion/vim files from the same tag

Options:
  --user                    Install for current user [default]
  --system                  Install system-wide
  --prefix DIR              Set software prefix; implies bin=DIR/bin,
                            home=DIR/share/taffish unless overridden
  --bin-dir DIR             Override executable install directory
  --taffish-home DIR        Override TAFFISH runtime home
  --repo OWNER/REPO         Gitee repository [taffish-org/taffish]
  --version VERSION         Release version [0.3.0]
  --provider PROVIDER       Raw provider: github or gitee [gitee]
  --raw-base-url URL        Override raw base URL. It should point at a tag,
                            for example .../raw/v0.3.0
  --os OS                   Override target OS (darwin|macos|linux)
  --arch ARCH               Override target arch (amd64|x86_64|arm64|aarch64)
  --taf-url URL             Override taf binary URL
  --taffish-url URL         Override taffish binary URL
  --share-url URL           Override completion/vim source with tar.gz archive
  --url URL                 Download full bundle tarball from explicit URL
  --archive FILE            Install from local tar.gz archive
  --config-profile PROFILE  Initialize taf config profile after install:
                            github, china, or none [china]
  --force-config            Replace existing config during config init
  --no-update               Do not run taf update after install
  --no-doctor               Do not run taf doctor --init after install
  -h, --help                Show this help

Release tarball layout:
  target/taf-<os>-<arch>-<version> (or bin/taf for legacy)
  target/taffish-<os>-<arch>-<version> (or bin/taffish for legacy)
  completion/
  vim-highlight/

Default GitHub raw URLs:
  https://raw.githubusercontent.com/<repo>/v<version>/target/taf-<os>-<arch>-<version>
  https://raw.githubusercontent.com/<repo>/v<version>/target/taffish-<os>-<arch>-<version>

Default Gitee raw URLs:
  https://gitee.com/<repo>/raw/v<version>/target/taf-<os>-<arch>-<version>
  https://gitee.com/<repo>/raw/v<version>/target/taffish-<os>-<arch>-<version>

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
        --config-profile)
            [ "$#" -ge 2 ] || taffish_die "--config-profile requires a value"
            TAFFISH_INSTALL_CONFIG_PROFILE=$2
            shift 2
            ;;
        --force-config)
            TAFFISH_INSTALL_CONFIG_FORCE=1
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
[ -n "$TAFFISH_INSTALL_RAW_BASE_URL" ] && TAFFISH_INSTALL_RAW_BASE_URL=$(taffish_strip_trailing_slash "$TAFFISH_INSTALL_RAW_BASE_URL")
[ -n "$TARGET_OS_OVERRIDE" ] && TARGET_OS_OVERRIDE=$(taffish_normalize_target_os "$TARGET_OS_OVERRIDE")
[ -n "$TARGET_ARCH_OVERRIDE" ] && TARGET_ARCH_OVERRIDE=$(taffish_normalize_target_arch "$TARGET_ARCH_OVERRIDE")

[ -n "$ARCHIVE" ] && [ -n "$URL" ] && taffish_die "--archive and --url can't be used together"

taffish_need_command tar
taffish_need_command mktemp

TMPDIR_INSTALL=$(mktemp -d "${TMPDIR:-/tmp}/taffish-install.XXXXXX") || taffish_die "failed to create temp directory"
cleanup() {
    rm -rf "$TMPDIR_INSTALL"
}
trap cleanup EXIT INT TERM HUP

if [ -n "$ARCHIVE" ] || [ -n "$URL" ]; then
    if [ -n "$SHARE_URL" ]; then
        taffish_warn "--share-url is ignored in bundle mode (--archive/--url)."
    fi

    if [ -n "$ARCHIVE" ]; then
        [ -f "$ARCHIVE" ] || taffish_die "archive does not exist: $ARCHIVE"
        TARBALL=$ARCHIVE
    else
        TARBALL=$TMPDIR_INSTALL/taffish.tar.gz
        taffish_download_file "$URL" "$TARBALL"
    fi

    STAGE_PARENT=$TMPDIR_INSTALL/stage
    mkdir -p "$STAGE_PARENT" || taffish_die "failed to create stage directory"
    tar -xzf "$TARBALL" -C "$STAGE_PARENT" || taffish_die "failed to unpack tarball"
    taffish_install_from_stage "$STAGE_PARENT"
else
    taffish_install_from_remote_raw
fi
