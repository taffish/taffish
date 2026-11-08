# External conformance tests for the standalone binary installers.
# This file is sourced by test/run-tests.sh.

_installer_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

_installer_mode() {
  mode=
  if stat -c '%a' "$1" >/dev/null 2>&1; then
    mode=$(stat -c '%a' "$1")
  else
    mode=$(stat -f '%Mp%Lp' "$1")
  fi
  case "$mode" in
    0???) mode=${mode#0} ;;
  esac
  printf '%s\n' "$mode"
}

_installer_write_fake_binary() {
  path=$1
  name=$2
  version=$3
  smoke_status=${4:-0}
  marker=${5:-fixture}
  cat > "$path" <<EOF
#!/bin/sh
# $marker
case "\${1:-}" in
  --version)
    printf '%s     %s\n' '$name' '$version'
    exit $smoke_status
    ;;
  doctor|config|update)
    exit "\${TAFFISH_FAKE_POST_STATUS:-0}"
    ;;
  *) exit 0 ;;
esac
EOF
  chmod 0755 "$path"
}

_installer_write_manifest() {
  target_dir=$1
  manifest=$target_dir/SHA256SUMS
  : > "$manifest"
  for name in taf taffish taffish-mcp; do
    file=$target_dir/$name-$OS-$ARCH-$TAFFISH_TEST_VERSION
    printf '%s  %s\n' "$(_installer_sha256 "$file")" "${file##*/}" >> "$manifest"
  done
}

_installer_make_fake_bundle() {
  root=$1
  version=${2:-$TAFFISH_TEST_VERSION}
  smoke_failure=${3:-}
  marker=${4:-fixture}
  mkdir -p "$root/target" \
    "$root/completion/bash" "$root/completion/zsh" "$root/completion/fish" \
    "$root/vim-highlight/syntax" "$root/vim-highlight/ftdetect"
  for name in taf taffish taffish-mcp; do
    status=0
    [ "$name" != "$smoke_failure" ] || status=71
    _installer_write_fake_binary \
      "$root/target/$name-$OS-$ARCH-$version" "$name" "$version" "$status" "$marker"
  done
  printf '# bash taf completion\n' > "$root/completion/bash/taf"
  printf '# bash taffish completion\n' > "$root/completion/bash/taffish"
  printf '# zsh taf completion\n' > "$root/completion/zsh/_taf"
  printf '# zsh taffish completion\n' > "$root/completion/zsh/_taffish"
  printf '# fish taf completion\n' > "$root/completion/fish/taf.fish"
  printf '# fish taffish completion\n' > "$root/completion/fish/taffish.fish"
  printf '" taf syntax\n' > "$root/vim-highlight/syntax/taf.vim"
  printf '" old taf syntax\n' > "$root/vim-highlight/syntax/old-taf.vim"
  printf '" taf ftdetect\n' > "$root/vim-highlight/ftdetect/taf.vim"
  _installer_write_manifest "$root/target"
}

_installer_archive_bundle() {
  bundle=$1
  archive=$2
  tar -czf "$archive" -C "$bundle" .
}

_installer_run_archive() {
  archive=$1
  bin_dir=$2
  home_dir=$3
  shift 3
  "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --archive "$archive" \
    --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$bin_dir" --taffish-home "$home_dir" \
    --no-doctor --no-update "$@"
}

_installer_assert_no_transaction_debris() {
  bin_dir=$1
  [ -d "$bin_dir" ] || return 0
  if find "$bin_dir" -maxdepth 1 -name '.taffish-install.*' -print | grep . >/dev/null 2>&1; then
    printf 'installer left transaction debris under %s\n' "$bin_dir" >&2
    return 1
  fi
}

_installer_case_template_and_dry_run() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-template
  mkdir -p "$dir"
  "$TAFFISH_TEST_REPO_ROOT/install/generate-installers.sh" --check || exit 1
  sh -n "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.template.sh" || exit 1
  sh -n "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" || exit 1
  sh -n "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.gitee.sh" || exit 1
  bash -n "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" || exit 1
  bash -n "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.gitee.sh" || exit 1

  for installer in install-taffish.sh install-taffish.gitee.sh; do
    help=$("$TAFFISH_TEST_REPO_ROOT/install/$installer" --help) || exit 1
    assert_contains "$help" 'English (en) and Chinese (zh) are built in' \
      'installer built-in language guidance' || exit 1
    assert_contains "$help" 'auto follows the host locale' \
      'installer default language guidance' || exit 1
    assert_contains "$help" 'taf config language zh' \
      'installer language command guidance' || exit 1
    assert_contains "$help" 'source selection does not select the CLI language' \
      'installer separates mirror and language' || exit 1
  done

  output=$("$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --dry-run --user --verify sha256 --retry 0 --connect-timeout 5 \
    --bin-dir "$dir/bin" --taffish-home "$dir/home") || exit 1
  assert_contains "$output" 'verification      : sha256' 'installer dry-run verification' || exit 1
  assert_contains "$output" 'SIF cache policy  : private' 'installer dry-run SIF policy' || exit 1
  assert_contains "$output" 'filesystem writes : disabled' 'installer dry-run mutation' || exit 1
  [ ! -e "$dir/bin" ] && [ ! -e "$dir/home" ] || {
    printf 'installer dry-run changed the filesystem\n' >&2
    exit 1
  }

  capture_command "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --dry-run --connect-timeout 0
  assert_capture_failure 'installer rejects zero timeout' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'must be greater than zero' \
    'installer timeout error' || exit 1
}

_installer_case_user_bundle_verification_and_idempotence() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-user-bundle
  bundle=$dir/bundle
  mkdir -p "$bundle/target" \
    "$bundle/completion/bash" "$bundle/completion/zsh" "$bundle/completion/fish" \
    "$bundle/vim-highlight/syntax" "$bundle/vim-highlight/ftdetect"
  cp "$TAF_BIN" "$bundle/target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  cp "$TAFFISH_BIN" "$bundle/target/taffish-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  cp "$TAFFISH_MCP_BIN" "$bundle/target/taffish-mcp-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  _installer_write_manifest "$bundle/target"
  cp "$TAFFISH_TEST_REPO_ROOT/completion/bash/taf" "$bundle/completion/bash/"
  cp "$TAFFISH_TEST_REPO_ROOT/completion/zsh/_taf" "$bundle/completion/zsh/"
  cp "$TAFFISH_TEST_REPO_ROOT/completion/fish/taf.fish" "$bundle/completion/fish/"
  cp "$TAFFISH_TEST_REPO_ROOT/vim-highlight/syntax/taf.vim" "$bundle/vim-highlight/syntax/"
  cp "$TAFFISH_TEST_REPO_ROOT/vim-highlight/ftdetect/taf.vim" "$bundle/vim-highlight/ftdetect/"
  archive=$dir/bundle.tar.gz
  _installer_archive_bundle "$bundle" "$archive"

  mkdir -p "$dir/os-home"
  printf '# unchanged\n' > "$dir/os-home/.bashrc"
  printf '" unchanged\n' > "$dir/os-home/.vimrc"
  output=$(HOME="$dir/os-home" _installer_run_archive \
    "$archive" "$dir/output/bin" "$dir/output/home") || exit 1
  assert_contains "$output" 'candidate smoke passed: taf' 'installer taf smoke' || exit 1
  assert_contains "$output" 'core binaries: installed' 'installer first action' || exit 1

  grep -F 'verification = "sha256"' \
    "$dir/output/home/install-receipt.toml" >/dev/null || exit 1
  grep -F 'source_kind = "bundle"' "$dir/output/home/install-receipt.toml" >/dev/null || exit 1
  grep -F 'scope = "user"' "$dir/output/home/install-receipt.toml" >/dev/null || exit 1
  grep -E '(url|token|password|credential)[[:space:]]*=' \
    "$dir/output/home/install-receipt.toml" >/dev/null 2>&1 && {
      printf 'install receipt contains a forbidden credential-like field\n' >&2
      exit 1
    }
  [ "$(_installer_mode "$dir/output/home/images/sif")" = 700 ] || exit 1
  for required in \
    apps index index/snapshots images/sif images/metadata images/locks images/tmp \
    bin cache/repos cache/downloads cache/build logs \
    share/completions/bash share/completions/zsh share/completions/fish \
    share/vim/syntax share/vim/ftdetect
  do
    [ -d "$dir/output/home/$required" ] || {
      printf 'installer did not create required directory: %s\n' "$required" >&2
      exit 1
    }
  done
  assert_eq '# unchanged' "$(cat "$dir/os-home/.bashrc")" 'installer keeps bashrc' || exit 1
  assert_eq '" unchanged' "$(cat "$dir/os-home/.vimrc")" 'installer keeps vimrc' || exit 1
  "$dir/output/bin/taf" --version | grep -F "$TAFFISH_TEST_VERSION" >/dev/null || exit 1
  "$dir/output/bin/taffish" --version | grep -F "$TAFFISH_TEST_VERSION" >/dev/null || exit 1
  "$dir/output/bin/taffish-mcp" --version | grep -F "$TAFFISH_TEST_VERSION" >/dev/null || exit 1

  second=$(HOME="$dir/os-home" _installer_run_archive \
    "$archive" "$dir/output/bin" "$dir/output/home") || exit 1
  assert_contains "$second" 'already match the requested release' \
    'installer idempotent reinstall' || exit 1
  grep -F 'binary_action = "unchanged"' "$dir/output/home/install-receipt.toml" >/dev/null || exit 1
  [ ! -e "$dir/output/home/.installer.lock" ] || exit 1
  _installer_assert_no_transaction_debris "$dir/output/bin" || exit 1

  # Use real installed binaries, not shell fixtures, to verify built-in locales.
  (
    export HOME="$dir/os-home" TAFFISH_CONFIG= TAFFISH_LANGUAGE=
    export LC_ALL= LC_MESSAGES= LANG=C
    export TAFFISH_SYSTEM_HOME="$dir/language-system"
    for provider in github gitee; do
      language_root=$dir/language-$provider
      export TAFFISH_USER_HOME="$language_root/home"
      script=$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh
      [ "$provider" != gitee ] || script=$TAFFISH_TEST_REPO_ROOT/install/install-taffish.gitee.sh
      "$script" --user --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
        --os "$OS" --arch "$ARCH" --bin-dir "$language_root/bin" \
        --taffish-home "$TAFFISH_USER_HOME" --no-doctor --no-update >/dev/null || exit 1
      [ ! -e "$TAFFISH_USER_HOME/share/locales" ] || exit 1
      if [ "$provider" = gitee ]; then
        grep -F 'language = "auto"' "$TAFFISH_USER_HOME/config.toml" >/dev/null || exit 1
      else
        [ ! -e "$TAFFISH_USER_HOME/config.toml" ] || exit 1
      fi
      for name in taf taffish taffish-mcp; do
        english=$("$language_root/bin/$name" --help) || exit 1
        chinese=$(LANG=zh_CN.UTF-8 "$language_root/bin/$name" --help) || exit 1
        assert_contains "$english" 'Usage:' "$provider installed $name auto English" || exit 1
        assert_contains "$chinese" '用法：' "$provider installed $name auto Chinese" || exit 1
        if [ "$name" != taffish-mcp ]; then
          assert_contains "$english" 'support@taffish.com' 'installed English contact' || exit 1
          assert_contains "$chinese" 'support@taffish.com' 'installed Chinese contact' || exit 1
        fi
      done
      "$language_root/bin/taf" config language zh >/dev/null || exit 1
      cp "$TAFFISH_USER_HOME/config.toml" "$language_root/config-before.toml"
      "$script" --user --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
        --os "$OS" --arch "$ARCH" --bin-dir "$language_root/bin" \
        --taffish-home "$TAFFISH_USER_HOME" --no-doctor --no-update >/dev/null || exit 1
      cmp "$language_root/config-before.toml" "$TAFFISH_USER_HOME/config.toml" || exit 1
      for name in taf taffish taffish-mcp; do
        chinese=$("$language_root/bin/$name" -h) || exit 1
        english=$(TAFFISH_LANGUAGE=en "$language_root/bin/$name" -h) || exit 1
        assert_contains "$chinese" '用法：' "$provider keeps saved Chinese under C locale" || exit 1
        assert_contains "$english" 'Usage:' "$provider one-command override" || exit 1
      done
      cmp "$language_root/config-before.toml" "$TAFFISH_USER_HOME/config.toml" || exit 1
    done
  ) || exit 1
}

_installer_gpg_prerequisites() {
  for _ig_tool in gpg gpgv; do
    command -v "$_ig_tool" >/dev/null 2>&1 || skip_case "$_ig_tool is required for installer GPG coverage"
  done
  for _ig_material in SHA256SUMS SHA256SUMS.asc TAFFISH-RELEASE-KEY.asc; do
    [ -f "$TAFFISH_TEST_REPO_ROOT/target/$_ig_material" ] || \
      skip_case "signed release material is missing: $_ig_material"
  done
  for _ig_name in taf taffish taffish-mcp; do
    case "$_ig_name" in
      taf) _ig_source=$TAF_BIN ;;
      taffish) _ig_source=$TAFFISH_BIN ;;
      taffish-mcp) _ig_source=$TAFFISH_MCP_BIN ;;
    esac
    _ig_asset=$_ig_name-$OS-$ARCH-$TAFFISH_TEST_VERSION
    if ! _ig_expected=$(awk -v asset="$_ig_asset" '
        $2 == asset || $2 == "*" asset { count++; value=$1 }
        END { if (count > 1) exit 1; if (count == 1) print value }
      ' "$TAFFISH_TEST_REPO_ROOT/target/SHA256SUMS"); then
      harness_fail "signed release manifest has duplicate entries: $_ig_asset"
      return 1
    fi
    _ig_actual=$(_installer_sha256 "$_ig_source") || return 1
    _ig_expected=$(printf '%s' "$_ig_expected" | tr '[:upper:]' '[:lower:]')
    if [ "$_ig_actual" != "$_ig_expected" ]; then
      if [ "$_ig_source" = "$TAFFISH_TEST_REPO_ROOT/target/$_ig_asset" ]; then
        harness_fail "release binary does not match signed manifest: $_ig_asset"
        return 1
      fi
      skip_case "selected local build is not covered by the signed release manifest: $_ig_asset"
    fi
  done
}

_installer_case_gpg_verification() {
  _installer_gpg_prerequisites || return 1
  gpg_dir=$TAFFISH_TEST_TMP_ROOT/installer-gpg
  gpg_bundle=$gpg_dir/bundle
  _installer_make_fake_bundle "$gpg_bundle"
  cp "$TAF_BIN" "$gpg_bundle/target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  cp "$TAFFISH_BIN" "$gpg_bundle/target/taffish-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  cp "$TAFFISH_MCP_BIN" "$gpg_bundle/target/taffish-mcp-$OS-$ARCH-$TAFFISH_TEST_VERSION"
  # Preserve the complete signed bytes, including entries for other platforms.
  cp "$TAFFISH_TEST_REPO_ROOT/target/SHA256SUMS" \
    "$TAFFISH_TEST_REPO_ROOT/target/SHA256SUMS.asc" \
    "$TAFFISH_TEST_REPO_ROOT/target/TAFFISH-RELEASE-KEY.asc" "$gpg_bundle/target/"
  gpg_archive=$gpg_dir/signed.tar.gz
  _installer_archive_bundle "$gpg_bundle" "$gpg_archive"
  for gpg_mode in gpg auto; do
    capture_command _installer_run_archive "$gpg_archive" \
      "$gpg_dir/installed/bin" "$gpg_dir/installed/home" --verify "$gpg_mode"
    assert_capture_success "installer $gpg_mode signed bundle" || return 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'verified GPG signature:' \
      "installer $gpg_mode GPG path executed" || return 1
    grep -F 'verification = "gpg"' "$gpg_dir/installed/home/install-receipt.toml" >/dev/null || return 1
    if [ "$gpg_mode" = auto ]; then
      assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'already match the requested release' \
        'signed reinstall is idempotent' || return 1
    fi
  done
  cp "$gpg_dir/installed/home/install-receipt.toml" "$gpg_dir/receipt-before.toml"

  for gpg_fault in signature manifest key binary missing-signature missing-key; do
    cp "$TAFFISH_TEST_REPO_ROOT/target/SHA256SUMS" \
      "$TAFFISH_TEST_REPO_ROOT/target/SHA256SUMS.asc" \
      "$TAFFISH_TEST_REPO_ROOT/target/TAFFISH-RELEASE-KEY.asc" "$gpg_bundle/target/"
    cp "$TAF_BIN" "$gpg_bundle/target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION"
    gpg_modes='gpg auto'
    case "$gpg_fault" in
      signature)
        printf 'invalid detached signature\n' > "$gpg_bundle/target/SHA256SUMS.asc"
        gpg_error='checksum manifest signature verification failed' ;;
      manifest)
        # Keep all selected binary hashes valid so rejection must use GPG.
        printf '\n' >> "$gpg_bundle/target/SHA256SUMS"
        gpg_error='checksum manifest signature verification failed' ;;
      key)
        cp "$TAFFISH_TEST_REPO_ROOT/test/installer/fixtures/untrusted-public-key.asc" \
          "$gpg_bundle/target/TAFFISH-RELEASE-KEY.asc"
        gpg_error='release key fingerprint mismatch' ;;
      binary)
        printf '\ntampered payload\n' >> "$gpg_bundle/target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION"
        gpg_error='SHA256 mismatch' ;;
      missing-signature)
        rm "$gpg_bundle/target/SHA256SUMS.asc"
        gpg_error='--verify gpg requires a checksum signature'; gpg_modes=gpg ;;
      missing-key)
        rm "$gpg_bundle/target/TAFFISH-RELEASE-KEY.asc"
        gpg_error='--verify gpg requires a release key'; gpg_modes=gpg ;;
    esac
    gpg_bad_archive=$gpg_dir/$gpg_fault.tar.gz
    _installer_archive_bundle "$gpg_bundle" "$gpg_bad_archive"
    for gpg_mode in $gpg_modes; do
      for gpg_destination in fresh installed; do
        if [ "$gpg_destination" = fresh ]; then
          gpg_output=$gpg_dir/rejected-$gpg_fault-$gpg_mode
        else
          gpg_output=$gpg_dir/installed
        fi
        capture_command _installer_run_archive "$gpg_bad_archive" \
          "$gpg_output/bin" "$gpg_output/home" --verify "$gpg_mode"
        assert_capture_failure "installer $gpg_mode rejects $gpg_fault ($gpg_destination)" || return 1
        assert_contains "$TAFFISH_CAPTURE_OUTPUT" "$gpg_error" \
          "installer $gpg_fault rejection reason" || return 1
        if [ "$gpg_destination" = fresh ]; then
          [ ! -e "$gpg_output/bin" ] && [ ! -e "$gpg_output/home" ] || return 1
        else
          cmp "$TAF_BIN" "$gpg_output/bin/taf" || return 1
          cmp "$TAFFISH_BIN" "$gpg_output/bin/taffish" || return 1
          cmp "$TAFFISH_MCP_BIN" "$gpg_output/bin/taffish-mcp" || return 1
          cmp "$gpg_dir/receipt-before.toml" "$gpg_output/home/install-receipt.toml" || return 1
          [ ! -e "$gpg_output/home/.installer.lock" ] || return 1
          _installer_assert_no_transaction_debris "$gpg_output/bin" || return 1
        fi
      done
    done
    printf '[gpg-check] %s rejected without installation changes\n' "$gpg_fault"
    rm "$gpg_bad_archive"
  done
}

_installer_expect_archive_failure() {
  archive=$1
  label=$2
  needle=$3
  output_root=$4
  capture_command _installer_run_archive \
    "$archive" "$output_root/bin" "$output_root/home"
  assert_capture_failure "$label" || return 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" "$needle" "$label" || return 1
  [ ! -e "$output_root/bin" ] && [ ! -e "$output_root/home" ]
}

_installer_case_checksum_failures() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-checksums
  mkdir -p "$dir"

  for mode in tampered missing duplicate no-manifest; do
    bundle=$dir/$mode-bundle
    _installer_make_fake_bundle "$bundle"
    taf_asset=taf-$OS-$ARCH-$TAFFISH_TEST_VERSION
    case "$mode" in
      tampered)
        printf '# tampered\n' >> "$bundle/target/$taf_asset"
        expected='SHA256 mismatch'
        ;;
      missing)
        awk -v asset="$taf_asset" '$2 != asset' \
          "$bundle/target/SHA256SUMS" > "$bundle/target/SHA256SUMS.new"
        mv "$bundle/target/SHA256SUMS.new" "$bundle/target/SHA256SUMS"
        expected='has no entry'
        ;;
      duplicate)
        duplicate_entry=$(awk -v asset="$taf_asset" \
          '$2 == asset { print; exit }' "$bundle/target/SHA256SUMS")
        [ -n "$duplicate_entry" ] || {
          printf 'checksum fixture cannot find asset: %s\n' "$taf_asset" >&2
          exit 1
        }
        printf '%s\n' "$duplicate_entry" >> "$bundle/target/SHA256SUMS"
        expected='duplicate entries'
        ;;
      no-manifest)
        rm -f "$bundle/target/SHA256SUMS"
        expected='requires a checksum manifest'
        ;;
    esac
    archive=$dir/$mode.tar.gz
    _installer_archive_bundle "$bundle" "$archive"
    if [ "$mode" = no-manifest ]; then
      capture_command _installer_run_archive \
        "$archive" "$dir/$mode-output/bin" "$dir/$mode-output/home" --verify sha256
      assert_capture_failure "installer $mode" || exit 1
      assert_contains "$TAFFISH_CAPTURE_OUTPUT" "$expected" "installer $mode" || exit 1
      [ ! -e "$dir/$mode-output/bin" ] && [ ! -e "$dir/$mode-output/home" ] || exit 1
    else
      _installer_expect_archive_failure "$archive" "installer $mode" "$expected" \
        "$dir/$mode-output" || exit 1
    fi
  done
}

_installer_case_archive_safety_and_custom_compatibility() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-archive-safety
  mkdir -p "$dir"
  python3 - "$dir/traversal.tar.gz" "$dir/symlink.tar.gz" <<'PY'
import io
import tarfile
import sys

traversal, symlink = sys.argv[1:]
with tarfile.open(traversal, "w:gz") as archive:
    payload = b"escape\n"
    info = tarfile.TarInfo("../../escape")
    info.size = len(payload)
    archive.addfile(info, io.BytesIO(payload))
with tarfile.open(symlink, "w:gz") as archive:
    info = tarfile.TarInfo("escape-link")
    info.type = tarfile.SYMTYPE
    info.linkname = "/etc/passwd"
    archive.addfile(info)
PY

  for kind in traversal symlink; do
    capture_command "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
      --archive "$dir/$kind.tar.gz" --verify none \
      --bin-dir "$dir/$kind-output/bin" --taffish-home "$dir/$kind-output/home" \
      --no-doctor --no-update
    assert_capture_failure "installer rejects $kind archive" || exit 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'unsafe archive' \
      "installer rejects $kind archive" || exit 1
    [ ! -e "$dir/$kind-output" ] || exit 1
  done

  bundle=$dir/no-manifest-bundle
  _installer_make_fake_bundle "$bundle"
  rm -f "$bundle/target/SHA256SUMS"
  archive=$dir/no-manifest.tar.gz
  _installer_archive_bundle "$bundle" "$archive"
  output=$(_installer_run_archive "$archive" \
    "$dir/compat-output/bin" "$dir/compat-output/home" 2>&1) || exit 1
  assert_contains "$output" 'payload remains unverified' \
    'custom auto source compatibility warning' || exit 1
  grep -F 'verification = "none"' \
    "$dir/compat-output/home/install-receipt.toml" >/dev/null || exit 1
}

_installer_case_raw_and_url_sources() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-raw-source
  raw=$dir/raw
  _installer_make_fake_bundle "$raw"
  _installer_archive_bundle "$raw" "$dir/bundle.tar.gz"
  mkdir -p "$dir/share-root"
  cp -R "$raw/completion" "$raw/vim-highlight" "$dir/share-root/"
  tar -czf "$dir/share.tar.gz" -C "$dir" share-root

  command -v curl >/dev/null 2>&1 || {
    printf 'curl is required for deterministic file:// installer source tests\n' >&2
    exit 1
  }
  base=file://$dir

  output=$("$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --raw-base-url "$base/raw" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/raw-output/bin" --taffish-home "$dir/raw-output/home" \
    --retry 0 --connect-timeout 5 --no-doctor --no-update) || exit 1
  assert_contains "$output" 'verification: sha256' 'raw source checksum' || exit 1
  grep -F 'source_kind = "raw"' "$dir/raw-output/home/install-receipt.toml" >/dev/null || exit 1

  taf_asset=taf-$OS-$ARCH-$TAFFISH_TEST_VERSION
  taffish_asset=taffish-$OS-$ARCH-$TAFFISH_TEST_VERSION
  mcp_asset=taffish-mcp-$OS-$ARCH-$TAFFISH_TEST_VERSION
  "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --raw-base-url "$base/raw" \
    --taf-url "$base/raw/target/$taf_asset" \
    --taffish-url "$base/raw/target/$taffish_asset" \
    --taffish-mcp-url "$base/raw/target/$mcp_asset" \
    --checksum-url "$base/raw/target/SHA256SUMS" \
    --share-url "$base/share.tar.gz" \
    --version "$TAFFISH_TEST_VERSION" --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/explicit-output/bin" --taffish-home "$dir/explicit-output/home" \
    --retry 0 --connect-timeout 5 --no-doctor --no-update >/dev/null || exit 1
  [ -f "$dir/explicit-output/home/share/completions/bash/taf" ] || exit 1

  "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --url "$base/bundle.tar.gz" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/url-output/bin" --taffish-home "$dir/url-output/home" \
    --retry 0 --connect-timeout 5 --no-doctor --no-update >/dev/null || exit 1
  "$dir/url-output/bin/taf" --version | grep -F "$TAFFISH_TEST_VERSION" >/dev/null || exit 1

  shim=$dir/download-shim
  mkdir -p "$shim"
  real_cp=$(command -v cp)
  cat > "$shim/curl" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "\${TAFFISH_TEST_CURL_LOG:?}"
out=
url=
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) out=\$2; shift 2 ;;
    http://*|https://*|file://*) url=\$1; shift ;;
    *) shift ;;
  esac
done
case "\$url" in
  */target/SHA256SUMS) exit 22 ;;
  */target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION)
    exec '$real_cp' '$raw/target/taf-$OS-$ARCH-$TAFFISH_TEST_VERSION' "\$out" ;;
  */target/taffish-$OS-$ARCH-$TAFFISH_TEST_VERSION)
    exec '$real_cp' '$raw/target/taffish-$OS-$ARCH-$TAFFISH_TEST_VERSION' "\$out" ;;
  */target/taffish-mcp-$OS-$ARCH-$TAFFISH_TEST_VERSION)
    exec '$real_cp' '$raw/target/taffish-mcp-$OS-$ARCH-$TAFFISH_TEST_VERSION' "\$out" ;;
  *) exit 22 ;;
esac
EOF
  chmod 0755 "$shim/curl"
  : > "$dir/curl.log"
  capture_command env PATH="$shim:$PATH" TAFFISH_TEST_CURL_LOG="$dir/curl.log" \
    "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --provider github --repo taffish/taffish \
    --version "$TAFFISH_TEST_VERSION" --os "$OS" --arch "$ARCH" \
    --retry 2 --connect-timeout 7 \
    --bin-dir "$dir/official-missing/bin" \
    --taffish-home "$dir/official-missing/home" \
    --no-doctor --no-update
  assert_capture_failure 'official raw source requires manifest' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'checksum manifest is unavailable' \
    'official raw source requires manifest' || exit 1
  grep -F -- '--retry 2 --connect-timeout 7' "$dir/curl.log" >/dev/null || exit 1
  [ ! -e "$dir/official-missing/bin" ] && \
    [ ! -e "$dir/official-missing/home" ] || exit 1

}

_installer_case_collision_lock_and_rollback() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-transaction
  bundle=$dir/bundle
  _installer_make_fake_bundle "$bundle" "$TAFFISH_TEST_VERSION" '' new
  archive=$dir/bundle.tar.gz
  _installer_archive_bundle "$bundle" "$archive"

  mkdir -p "$dir/lock-output/home/.installer.lock"
  capture_command _installer_run_archive "$archive" \
    "$dir/lock-output/bin" "$dir/lock-output/home"
  assert_capture_failure 'installer active lock' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'another installer may be active' \
    'installer active lock' || exit 1
  if find "$dir/lock-output/bin" -type f -print 2>/dev/null | grep . >/dev/null 2>&1; then
    printf 'installer lock failure wrote a core binary\n' >&2
    exit 1
  fi

  mkdir -p "$dir/collision-output/bin"
  printf '#!/bin/sh\nprintf "foreign\\n"\n' > "$dir/collision-output/bin/taf"
  chmod 0755 "$dir/collision-output/bin/taf"
  capture_command _installer_run_archive "$archive" \
    "$dir/collision-output/bin" "$dir/collision-output/home"
  assert_capture_failure 'installer collision' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'refusing to replace non-TAFFISH command' \
    'installer collision' || exit 1
  assert_eq foreign "$($dir/collision-output/bin/taf)" 'installer preserves collision' || exit 1
  _installer_run_archive "$archive" \
    "$dir/collision-output/bin" "$dir/collision-output/home" --force >/dev/null || exit 1
  "$dir/collision-output/bin/taf" --version | grep -F "$TAFFISH_TEST_VERSION" >/dev/null || exit 1

  # New binaries take the receipt backup path; matching binaries go straight
  # to the receipt writer. Neither path may replace a symlink.
  for receipt_case in fresh matching; do
    receipt_root=$dir/receipt-link-$receipt_case
    mkdir -p "$receipt_root/home"
    if [ "$receipt_case" = matching ]; then
      _installer_run_archive "$archive" "$receipt_root/bin" "$receipt_root/home" >/dev/null || exit 1
      mv "$receipt_root/home/install-receipt.toml" "$receipt_root/home/saved-receipt" || exit 1
      saved_receipt_hash=$(_installer_sha256 "$receipt_root/home/saved-receipt") || exit 1
    fi
    ln -s saved-receipt "$receipt_root/home/install-receipt.toml" || exit 1
    capture_command _installer_run_archive "$archive" "$receipt_root/bin" "$receipt_root/home"
    assert_capture_failure "installer $receipt_case symlink receipt" || exit 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'refusing to replace non-regular install receipt' \
      "installer $receipt_case symlink receipt" || exit 1
    [ -L "$receipt_root/home/install-receipt.toml" ] || exit 1
    if [ "$receipt_case" = matching ]; then
      assert_eq "$saved_receipt_hash" "$(_installer_sha256 "$receipt_root/home/saved-receipt")" \
        'installer preserves linked receipt' || exit 1
    else
      [ ! -e "$receipt_root/home/saved-receipt" ] || exit 1
    fi
  done

  mkdir -p "$dir/rollback-output/bin" "$dir/mv-wrapper"
  for name in taf taffish taffish-mcp; do
    _installer_write_fake_binary "$dir/rollback-output/bin/$name" \
      "$name" 0.10.1 0 old
  done
  real_mv=$(command -v mv)
  cat > "$dir/mv-wrapper/mv" <<EOF
#!/bin/sh
case "\${TAFFISH_TEST_MV_FAILURE:-}:\${1:-}:\${2:-}" in
  binary:*/new-taffish:*/taffish) exit 97 ;;
  receipt:*/.install-receipt.*:*/install-receipt.toml) exit 98 ;;
esac
exec '$real_mv' "\$@"
EOF
  chmod 0755 "$dir/mv-wrapper/mv"
  capture_command env TAFFISH_TEST_MV_FAILURE=binary PATH="$dir/mv-wrapper:$PATH" \
    "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/rollback-output/bin" --taffish-home "$dir/rollback-output/home" \
    --no-doctor --no-update
  assert_capture_failure 'installer transaction rollback' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'rolling back incomplete core binary installation' \
    'installer transaction rollback' || exit 1
  for name in taf taffish taffish-mcp; do
    "$dir/rollback-output/bin/$name" --version | grep -F '0.10.1' >/dev/null || exit 1
  done
  [ ! -e "$dir/rollback-output/home/.installer.lock" ] || exit 1
  _installer_assert_no_transaction_debris "$dir/rollback-output/bin" || exit 1

  mkdir -p "$dir/receipt-rollback/bin" "$dir/receipt-rollback/home"
  for name in taf taffish taffish-mcp; do
    _installer_write_fake_binary "$dir/receipt-rollback/bin/$name" \
      "$name" 0.10.1 0 old
  done
  printf 'old receipt\n' > "$dir/receipt-rollback/home/install-receipt.toml"
  capture_command env TAFFISH_TEST_MV_FAILURE=receipt PATH="$dir/mv-wrapper:$PATH" \
    "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/receipt-rollback/bin" \
    --taffish-home "$dir/receipt-rollback/home" \
    --no-doctor --no-update
  assert_capture_failure 'installer receipt rollback' || exit 1
  assert_contains "$TAFFISH_CAPTURE_OUTPUT" 'failed to commit install receipt' \
    'installer receipt rollback' || exit 1
  for name in taf taffish taffish-mcp; do
    "$dir/receipt-rollback/bin/$name" --version | grep -F '0.10.1' >/dev/null || exit 1
  done
  assert_eq 'old receipt' \
    "$(cat "$dir/receipt-rollback/home/install-receipt.toml")" \
    'installer restores previous receipt' || exit 1
  if find "$dir/receipt-rollback/home" -maxdepth 1 \
      -name '.install-receipt.*' -print | grep . >/dev/null 2>&1; then
    printf 'installer left receipt staging debris after rollback\n' >&2
    exit 1
  fi
  _installer_assert_no_transaction_debris "$dir/receipt-rollback/bin" || exit 1
}

_installer_case_post_install_warnings() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-post-install
  bundle=$dir/bundle
  _installer_make_fake_bundle "$bundle"
  archive=$dir/bundle.tar.gz
  _installer_archive_bundle "$bundle" "$archive"
  output=$(TAFFISH_FAKE_POST_STATUS=7 \
    "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/output/bin" --taffish-home "$dir/output/home" \
    --config-profile github 2>&1) || exit 1
  assert_contains "$output" 'taf doctor --init --user failed' 'installer doctor warning' || exit 1
  assert_contains "$output" 'taf config init --user --github failed' 'installer config warning' || exit 1
  assert_contains "$output" 'taf update --user failed' 'installer update warning' || exit 1
  assert_contains "$output" 'post-install: doctor=warning config=warning update=warning' \
    'installer post status summary' || exit 1
  [ -x "$dir/output/bin/taf" ] && [ -f "$dir/output/home/install-receipt.toml" ] || exit 1
}

_installer_case_system_permissions() {
  dir=$TAFFISH_TEST_TMP_ROOT/installer-system
  bundle=$dir/bundle
  _installer_make_fake_bundle "$bundle"
  archive=$dir/bundle.tar.gz
  _installer_archive_bundle "$bundle" "$archive"

  if [ "$(id -u)" -ne 0 ]; then
    capture_command "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
      --system --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
      --os "$OS" --arch "$ARCH" \
      --bin-dir "$dir/nonroot/bin" --taffish-home "$dir/nonroot/home" \
      --no-doctor --no-update
    assert_capture_failure 'installer non-root system rejection' || exit 1
    assert_contains "$TAFFISH_CAPTURE_OUTPUT" '--system requires root privileges' \
      'installer non-root system rejection' || exit 1
    [ ! -e "$dir/nonroot" ] || exit 1

    output=$("$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
      --dry-run --system --shared-sif-cache \
      --bin-dir "$dir/dry/bin" --taffish-home "$dir/dry/home") || exit 1
    assert_contains "$output" 'SIF cache policy  : shared' 'installer shared dry-run' || exit 1
    [ ! -e "$dir/dry" ] || exit 1
    return 0
  fi

  "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --system --archive "$archive" --version "$TAFFISH_TEST_VERSION" \
    --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/admin/bin" --taffish-home "$dir/admin/home" \
    --no-doctor --no-update >/dev/null || exit 1
  [ "$(_installer_mode "$dir/admin/home/images/sif")" = 755 ] || exit 1
  grep -F 'scope = "system"' "$dir/admin/home/install-receipt.toml" >/dev/null || exit 1

  mkdir -p "$dir/shared/home/images/sif" "$dir/shared/home/keep"
  chmod 0777 "$dir/shared/home/images/sif"
  chmod 0701 "$dir/shared/home/keep"
  "$TAFFISH_TEST_REPO_ROOT/install/install-taffish.sh" \
    --system --shared-sif-cache --archive "$archive" \
    --version "$TAFFISH_TEST_VERSION" --os "$OS" --arch "$ARCH" \
    --bin-dir "$dir/shared/bin" --taffish-home "$dir/shared/home" \
    --no-doctor --no-update >/dev/null || exit 1
  [ "$(_installer_mode "$dir/shared/home/images/sif")" = 1777 ] || exit 1
  [ "$(_installer_mode "$dir/shared/home/keep")" = 701 ] || exit 1
}

run_installer_conformance() {
  run_case "installer/verification-fixture-contract" \
    python3 -I "$TAFFISH_TEST_REPO_ROOT/test/installer/fixture-tests.py"
  run_case "installer/template-and-dry-run" \
    _installer_case_template_and_dry_run
  run_case "installer/user-bundle-verification-idempotence" \
    _installer_case_user_bundle_verification_and_idempotence
  run_case "installer/gpg-verification" \
    _installer_case_gpg_verification
  run_case "installer/checksum-failures" \
    _installer_case_checksum_failures
  run_case "installer/archive-safety-custom-compatibility" \
    _installer_case_archive_safety_and_custom_compatibility
  run_case "installer/raw-and-url-sources" \
    _installer_case_raw_and_url_sources
  run_case "installer/collision-lock-rollback" \
    _installer_case_collision_lock_and_rollback
  run_case "installer/post-install-warnings" \
    _installer_case_post_install_warnings
  run_case "installer/system-permissions" \
    _installer_case_system_permissions
}
