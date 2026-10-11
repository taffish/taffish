# External conformance tests for built-in and custom TAFFISH languages.
# This file is sourced by test/run-tests.sh.

_i18n_option_tokens() {
  python3 -c '
import re
import sys

text = sys.stdin.read()
pattern = r"(?<![A-Za-z0-9_-])--[A-Za-z0-9][A-Za-z0-9-]*|(?<![A-Za-z0-9_-])-[A-Za-z](?![A-Za-z0-9_-])"
print("\n".join(sorted(set(re.findall(pattern, text)))))
'
}

_i18n_assert_top_help_layout() {
  python3 -c '
import sys
import unicodedata

app, language = sys.argv[1:]
text = sys.stdin.read()
lines = text.splitlines()
sections = {
    ("taf", "en"): ["Usage:", "Project commands:", "Hub commands:",
                    "System commands:", "Getting started:", "Language:", "More information:"],
    ("taf", "zh"): ["用法：", "项目命令：", "Hub 命令：", "系统命令：", "入门：", "语言：", "更多信息："],
    ("taffish", "en"): ["Usage:", "Input:", "Container settings:", "Examples:", "Language:", "More information:"],
    ("taffish", "zh"): ["用法：", "输入：", "容器设置：", "示例：", "语言：", "更多信息："],
}[app, language]
positions = [lines.index(section) for section in sections]
assert positions == sorted(positions), (app, language, positions)
assert len(lines) <= (60 if app == "taf" else 45), (app, len(lines))
for line in lines:
    assert all(ord(c) >= 32 for c in line), repr(line)
    width = sum(0 if unicodedata.combining(c) else
                2 if unicodedata.east_asian_width(c) in ("W", "F") else 1
                for c in line)
    assert width <= 80, (app, language, width, line)
for contact in ("https://taffish.com", "https://taffish.github.io/", "support@taffish.com"):
    assert text.count(contact) == 1, (app, contact)
assert "auto" in text and ("[default]" if language == "en" else "[默认]") in text
' "$1" "$2"
}

_i18n_assert_help_pair() {
  command=$1
  user_home=$2
  system_home=$3

  if [ -n "$command" ]; then
    english=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" "$command" --help) || return 1
    english_short=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" "$command" -h) || return 1
    english_dispatch=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" help "$command") || return 1
    chinese=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" "$command" --help) || return 1
    chinese_short=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" "$command" -h) || return 1
    chinese_dispatch=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" help "$command") || return 1
    label="taf $command help"
  else
    english=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" --help) || return 1
    english_short=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" -h) || return 1
    english_dispatch=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" help) || return 1
    chinese=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" --help) || return 1
    chinese_short=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" -h) || return 1
    chinese_dispatch=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" help) || return 1
    label="taf help"
  fi

  assert_eq "$english_short" "$english" "$label English -h/--help" || return 1
  assert_eq "$english_dispatch" "$english" \
    "$label English help dispatch" || return 1
  assert_eq "$chinese_short" "$chinese" "$label Chinese -h/--help" || return 1
  assert_eq "$chinese_dispatch" "$chinese" \
    "$label Chinese help dispatch" || return 1
  assert_contains "$english" "Usage:" "$label English" || return 1
  assert_contains "$chinese" "用法：" "$label Chinese" || return 1
  english_options=$(printf '%s' "$english" | _i18n_option_tokens) || return 1
  chinese_options=$(printf '%s' "$chinese" | _i18n_option_tokens) || return 1
  assert_eq "$english_options" "$chinese_options" \
    "$label option tokens" || return 1
  if [ -z "$command" ]; then
    printf '%s\n' "$english" | _i18n_assert_top_help_layout taf en || return 1
    printf '%s\n' "$chinese" | _i18n_assert_top_help_layout taf zh || return 1
  else
    assert_not_contains "$english" 'support@taffish.com' "$label no footer" || return 1
    assert_not_contains "$chinese" 'support@taffish.com' "$label no footer" || return 1
  fi
}

_i18n_case_builtin_help_and_errors() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-builtins
  user_home=$dir/user-home
  system_home=$dir/system-home
  mkdir -p "$user_home" "$system_home"

  # No saved preference defaults to auto and follows a recognized host locale.
  default_taf=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" "$TAF_BIN" --help) || return 1
  assert_contains "$default_taf" "用法：" "taf defaults to auto" || return 1

  default_taffish=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" "$TAFFISH_BIN" --help) || return 1
  assert_contains "$default_taffish" "用法：" \
    "taffish defaults to auto" || return 1

  default_mcp=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" "$TAFFISH_MCP_BIN" --help) || return 1
  assert_contains "$default_mcp" "用法：" \
    "taffish-mcp help defaults to auto" || return 1

  fallback_taf=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=C TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" "$TAF_BIN" --help) || return 1
  assert_contains "$fallback_taf" "Usage:" \
    "default auto falls back to English for C locale" || return 1

  _i18n_assert_help_pair "" "$user_home" "$system_home" || return 1
  for command in \
    new check compile build run publish update search info install outdated \
    upgrade prune uninstall list which doctor config history
  do
    _i18n_assert_help_pair "$command" "$user_home" "$system_home" || return 1
  done

  taffish_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" --help) || return 1
  assert_contains "$taffish_zh" "用法：" "taffish built-in Chinese help" || return 1
  taffish_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" --help) || return 1
  taffish_en_short=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" -h) || return 1
  taffish_zh_short=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" -h) || return 1

  mcp_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" --help) || return 1
  mcp_en_short=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" -h) || return 1
  mcp_en_dispatch=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" help) || return 1
  mcp_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" --help) || return 1
  mcp_zh_short=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" -h) || return 1
  mcp_zh_dispatch=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" help) || return 1
  assert_eq "$mcp_en_short" "$mcp_en" \
    "taffish-mcp English -h/--help" || return 1
  assert_eq "$mcp_en_dispatch" "$mcp_en" \
    "taffish-mcp English help dispatch" || return 1
  assert_eq "$mcp_zh_short" "$mcp_zh" \
    "taffish-mcp Chinese -h/--help" || return 1
  assert_eq "$mcp_zh_dispatch" "$mcp_zh" \
    "taffish-mcp Chinese help dispatch" || return 1
  assert_contains "$mcp_en" "Usage:" \
    "taffish-mcp built-in English help" || return 1
  assert_contains "$mcp_zh" "用法：" \
    "taffish-mcp built-in Chinese help" || return 1
  mcp_en_options=$(printf '%s' "$mcp_en" | _i18n_option_tokens) || return 1
  mcp_zh_options=$(printf '%s' "$mcp_zh" | _i18n_option_tokens) || return 1
  assert_eq "$mcp_en_options" "$mcp_zh_options" \
    "taffish-mcp help option tokens" || return 1
  assert_eq "$taffish_en_short" "$taffish_en" \
    "taffish English -h/--help" || return 1
  assert_eq "$taffish_zh_short" "$taffish_zh" \
    "taffish Chinese -h/--help" || return 1
  printf '%s\n' "$taffish_en" | _i18n_assert_top_help_layout taffish en || return 1
  printf '%s\n' "$taffish_zh" | _i18n_assert_top_help_layout taffish zh || return 1
  for binary in "$TAF_BIN" "$TAFFISH_BIN"; do
    version_en=$(env TAFFISH_LANGUAGE=en "$binary" --version) || return 1
    version_zh=$(env TAFFISH_LANGUAGE=zh "$binary" -v) || return 1
    assert_eq "$version_en" "$version_zh" 'version aliases and languages' || return 1
    assert_eq "$(printf '%s\n' "$version_en" | wc -l | tr -d ' ')" 1 \
      'version remains one line' || return 1
    assert_not_contains "$version_en" 'https://' 'version has no footer' || return 1
  done
  assert_eq \
    "$(printf '%s' "$taffish_en" | _i18n_option_tokens)" \
    "$(printf '%s' "$taffish_zh" | _i18n_option_tokens)" \
    "taffish help option tokens" || return 1

  set +e
  error_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --i18n-unknown 2>&1)
  status_en=$?
  error_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --i18n-unknown 2>&1)
  status_zh=$?
  set -e
  [ "$status_en" -ne 0 ] || harness_fail "English unknown option succeeded"
  [ "$status_zh" -ne 0 ] || harness_fail "Chinese unknown option succeeded"
  assert_eq "$status_en" "$status_zh" "localized error exit code" || return 1
  assert_contains "$error_en" "unknown option" "English unknown option" || return 1
  assert_contains "$error_zh" "未知选项" "Chinese unknown option" || return 1
  assert_contains "$error_zh" "--i18n-unknown" \
    "Chinese error preserves option" || return 1

}

_i18n_case_unicode_stdio_pipes() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-unicode-stdio-pipes
  user_home=$dir/user-home
  system_home=$dir/system-home
  mkdir -p "$user_home" "$system_home"

  env LC_ALL=C LANG=C TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help | cat > "$dir/taf-help.txt"
  assert_contains "$(cat "$dir/taf-help.txt")" "用法：" \
    "taf Chinese help through stdout pipe" || return 1

  env LC_ALL=C LANG=C TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" --help | cat > "$dir/taffish-help.txt"
  assert_contains "$(cat "$dir/taffish-help.txt")" "用法：" \
    "taffish Chinese help through stdout pipe" || return 1

  env LC_ALL=C LANG=C TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" --help | cat > "$dir/mcp-help.txt"
  assert_contains "$(cat "$dir/mcp-help.txt")" "用法：" \
    "taffish-mcp Chinese help through stdout pipe" || return 1

  set +e
  env LC_ALL=C LANG=C TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --unicode-stdio-unknown \
    > "$dir/error-stdout.txt" 2> "$dir/error-stderr.txt"
  status=$?
  set -e
  [ "$status" -ne 0 ] || harness_fail "localized invalid command succeeded"
  [ ! -s "$dir/error-stdout.txt" ] || \
    harness_fail "localized error leaked to stdout"
  assert_contains "$(cat "$dir/error-stderr.txt")" "未知选项" \
    "taf Chinese error through stderr descriptor" || return 1
}

_i18n_case_resolution_priority() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-priority
  user_home=$dir/user-home
  system_home=$dir/system-home
  explicit_config=$dir/explicit.toml
  empty_user=$dir/empty-user
  empty_system=$dir/empty-system
  mkdir -p "$user_home" "$system_home" "$empty_user" "$empty_system"
  printf 'language = "zh"\n' > "$system_home/config.toml"

  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$output" "用法：" "system config language" || return 1

  printf 'language = "en"\n' > "$user_home/config.toml"
  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$output" "Usage:" "user config overrides system" || return 1

  printf 'language = "zh"\n' > "$explicit_config"
  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG="$explicit_config" \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$output" "用法：" "explicit config overrides user" || return 1

  output=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG="$explicit_config" \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$output" "Usage:" "environment overrides explicit config" || return 1

  printf 'language = "auto"\n' > "$user_home/config.toml"
  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$empty_system" "$TAF_BIN" --help) || return 1
  assert_contains "$output" "用法：" "auto follows locale environment" || return 1

  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$empty_user" \
    TAFFISH_SYSTEM_HOME="$empty_system" "$TAF_BIN" --help) || return 1
  assert_contains "$output" "用法：" \
    "missing language config defaults to auto" || return 1

  printf 'language = "en"\n' > "$empty_user/config.toml"
  output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$empty_user" \
    TAFFISH_SYSTEM_HOME="$empty_system" "$TAF_BIN" --help) || return 1
  assert_contains "$output" "Usage:" \
    "explicit English remains deterministic" || return 1
}

_i18n_case_external_locale_safety() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-external
  user_home=$dir/user-home
  system_home=$dir/system-home
  mkdir -p \
    "$user_home/share/locales/ja/help" \
    "$system_home/share/locales/ja/help" \
    "$user_home/share/locales/zh/help" \
    "$user_home/share/locales/de" \
    "$user_home/share/locales/fr"

  printf 'SYSTEM JA HELP\n' > "$system_home/share/locales/ja/help/taf.txt"
  printf 'USER JA HELP\n' > "$user_home/share/locales/ja/help/taf.txt"
  cat > "$system_home/share/locales/ja/messages.json" <<'EOF_SYSTEM_JA'
{"taf.cli.unknown-option":"SYSTEM JA {command} {option}"}
EOF_SYSTEM_JA
  cat > "$user_home/share/locales/ja/messages.json" <<'EOF_USER_JA'
{"taf.cli.unknown-option":"USER JA {command} {option}"}
EOF_USER_JA

  output=$(env TAFFISH_LANGUAGE=ja-JP TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$output" "USER JA HELP" \
    "custom locale exact/base and user/system priority" || return 1

  fallback=$(env TAFFISH_LANGUAGE=ja-JP TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config --help) || return 1
  assert_contains "$fallback" "Usage:" "missing custom help falls back to English" || return 1

  set +e
  custom_error=$(env TAFFISH_LANGUAGE=ja-JP TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --custom-option 2>&1)
  custom_status=$?
  set -e
  [ "$custom_status" -ne 0 ] || harness_fail "custom locale unknown option succeeded"
  assert_contains "$custom_error" "USER JA" \
    "custom message uses user catalog" || return 1
  assert_contains "$custom_error" "--custom-option" \
    "custom message renders named placeholder" || return 1

  printf 'BAD BUILTIN OVERRIDE\n' > \
    "$user_home/share/locales/zh/help/taf.txt"
  builtin=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$builtin" "用法：" "built-in zh remains embedded" || return 1
  assert_not_contains "$builtin" "BAD BUILTIN OVERRIDE" \
    "external locale cannot override built-in zh" || return 1

  printf '#.(error "unsafe")\n' > \
    "$user_home/share/locales/de/messages.json"
  set +e
  invalid_json=$(env TAFFISH_LANGUAGE=de TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --bad-json 2>&1)
  invalid_status=$?
  set -e
  [ "$invalid_status" -ne 0 ] || harness_fail "invalid locale JSON command succeeded"
  assert_contains "$invalid_json" "unknown option" \
    "invalid and Lisp-like locale data falls back safely" || return 1

  cat > "$user_home/share/locales/fr/messages.json" <<'EOF_BAD_PLACEHOLDER'
{"taf.cli.unknown-option":"MAUVAIS {wrong}"}
EOF_BAD_PLACEHOLDER
  set +e
  invalid_placeholder=$(env TAFFISH_LANGUAGE=fr TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" build --bad-placeholder 2>&1)
  placeholder_status=$?
  set -e
  [ "$placeholder_status" -ne 0 ] || \
    harness_fail "invalid placeholder locale command succeeded"
  assert_contains "$invalid_placeholder" "unknown option" \
    "placeholder mismatch falls back to English" || return 1
  assert_not_contains "$invalid_placeholder" "MAUVAIS" \
    "placeholder mismatch translation rejected" || return 1
}

_i18n_case_human_config_and_doctor() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-human-output
  user_home=$dir/user-home
  system_home=$dir/system-home
  os_home=$dir/os-home
  mkdir -p "$user_home" "$system_home" "$os_home"

  config_en=$(env HOME="$os_home" TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config) || return 1
  config_zh=$(env HOME="$os_home" TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config) || return 1
  assert_contains "$config_en" "Effective config:" "config English output" || return 1
  assert_contains "$config_zh" "生效配置：" "config Chinese output" || return 1
  assert_contains "$config_en" "<default>" "config English default sentinel" || return 1
  assert_contains "$config_zh" "<默认>" "config Chinese default sentinel" || return 1
  assert_contains "$config_zh" "<未设置>" "config Chinese unset sentinel" || return 1
  assert_contains "$config_zh" "TAFFISH_USER_HOME" \
    "config machine key remains stable" || return 1

  doctor_en=$(env HOME="$os_home" TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" doctor --user --shell bash) || return 1
  doctor_zh=$(env HOME="$os_home" TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" doctor --user --shell bash) || return 1
  assert_contains "$doctor_en" "Diagnostics:" "doctor English output" || return 1
  assert_contains "$doctor_zh" "诊断：" "doctor Chinese output" || return 1
  assert_contains "$doctor_zh" "Shell 补全" \
    "doctor Chinese diagnostic name" || return 1
}

_i18n_case_language_management() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-language-management
  user_home=$dir/user-home
  system_home=$dir/system-home
  config_file=$user_home/config.toml
  github_init_home=$dir/github-init-home
  china_init_home=$dir/china-init-home
  mkdir -p \
    "$user_home/share/locales/ja" \
    "$user_home/share/locales/it" \
    "$user_home/share/locales/de" \
    "$system_home/share/locales/ja" \
    "$github_init_home" \
    "$china_init_home"

  env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$github_init_home" \
    TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config init --user --github >/dev/null || return 1
  grep -F 'language = "auto"' "$github_init_home/config.toml" >/dev/null || \
    harness_fail "GitHub config template did not default to auto"

  env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$china_init_home" \
    TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config init --user --china >/dev/null || return 1
  grep -F 'language = "auto"' "$china_init_home/config.toml" >/dev/null || \
    harness_fail "China config template did not default to auto"

  cat > "$config_file" <<'EOF_LANGUAGE_CONFIG'
# keep this comment
schema_version = "taffish.config/v1"
profile = "china"
language = "en"  # keep language comment
future_key = "preserve-me"

[index]
url = "file:///custom-index.json"
EOF_LANGUAGE_CONFIG
  printf '{"sample":"system"}\n' > \
    "$system_home/share/locales/ja/messages.json"
  printf 'SYSTEM EXAMPLE\n' > \
    "$system_home/share/locales/ja/example.txt"
  printf '{"sample":"user"}\n' > \
    "$user_home/share/locales/ja/messages.json"
  printf '\nUSER EXAMPLE\nignored\n' > \
    "$user_home/share/locales/ja/example.txt"
  printf 'EXAMPLE ONLY\n' > \
    "$user_home/share/locales/it/example.txt"
  printf 'not json\n' > \
    "$user_home/share/locales/de/messages.json"

  shown=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language --show) || return 1
  assert_contains "$shown" "[TAF] language configuration" \
    "language show header" || return 1
  assert_contains "$shown" "configured" "language show configured" || return 1
  assert_contains "$shown" "display language" "language show displayed" || return 1
  assert_contains "$shown" "TAFFISH_LANGUAGE environment" \
    "language show override source" || return 1
  assert_contains "$shown" "en" "language show built-in en" || return 1
  assert_contains "$shown" "zh" "language show built-in zh" || return 1
  assert_contains "$shown" "ja" "language show external ja" || return 1
  assert_contains "$shown" "USER EXAMPLE" "user language shadows system" || return 1
  assert_not_contains "$shown" "  it " \
    "example-only directory is not available" || return 1
  assert_not_contains "$shown" "  de " \
    "malformed locale is not available" || return 1

  switched=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language zh) || return 1
  assert_contains "$switched" "[TAF] 语言配置" \
    "language switch uses fresh Chinese selection" || return 1
  assert_contains "$switched" "已保存" "language switch reports saved value" || return 1
  grep -F 'language = "zh"  # keep language comment' "$config_file" >/dev/null || \
    harness_fail "language setter did not preserve inline comment"
  grep -F 'future_key = "preserve-me"' "$config_file" >/dev/null || \
    harness_fail "language setter removed future config key"
  grep -F 'profile = "china"' "$config_file" >/dev/null || \
    harness_fail "language setter changed source profile"
  grep -F 'url = "file:///custom-index.json"' "$config_file" >/dev/null || \
    harness_fail "language setter changed index URL"

  chinese_help=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" --help) || return 1
  assert_contains "$chinese_help" "用法：" \
    "saved Chinese affects next process" || return 1

  masked=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language zh) || return 1
  assert_contains "$masked" "TAFFISH_LANGUAGE environment" \
    "environment override remains visible" || return 1
  assert_contains "$masked" "display language" \
    "masked result reports displayed language" || return 1

  auto_output=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language auto) || return 1
  assert_contains "$auto_output" "主机 locale 环境" \
    "auto reports locale environment source" || return 1
  auto_help=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= LC_ALL= \
    LC_MESSAGES= LANG=zh_CN.UTF-8 TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" "$TAF_BIN" --help) || return 1
  assert_contains "$auto_help" "用法：" "saved auto follows locale" || return 1

  external=$(env TAFFISH_LANGUAGE= TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language ja) || return 1
  assert_contains "$external" "saved" "valid external language is selectable" || return 1

  set +e
  unavailable=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" config language it 2>&1)
  unavailable_status=$?
  set -e
  [ "$unavailable_status" -ne 0 ] || \
    harness_fail "example-only unavailable language was accepted"
  assert_contains "$unavailable" "unavailable language" \
    "unknown language fails with guidance" || return 1
  assert_contains "$unavailable" "taf config language --show" \
    "unknown language points to discovery" || return 1

  assert_contains "$(cat "$TAFFISH_TEST_REPO_ROOT/completion/bash/taf")" \
    "language en zh auto" "bash completion exposes languages" || return 1
  assert_contains "$(cat "$TAFFISH_TEST_REPO_ROOT/completion/zsh/_taf")" \
    "show path init language" "zsh completion exposes language action" || return 1
  assert_contains "$(cat "$TAFFISH_TEST_REPO_ROOT/completion/fish/taf.fish")" \
    "show path init language" "fish completion exposes language action" || return 1
}

_i18n_assert_failure_pair() {
  pair_user_home=$1
  pair_system_home=$2
  pair_label=$3
  pair_stable_token=$4
  shift 4

  set +e
  pair_english=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$pair_user_home" \
    TAFFISH_SYSTEM_HOME="$pair_system_home" "$@" 2>&1)
  pair_english_status=$?
  pair_chinese=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$pair_user_home" \
    TAFFISH_SYSTEM_HOME="$pair_system_home" "$@" 2>&1)
  pair_chinese_status=$?
  set -e

  [ "$pair_english_status" -ne 0 ] || \
    harness_fail "$pair_label English command unexpectedly succeeded"
  [ "$pair_chinese_status" -ne 0 ] || \
    harness_fail "$pair_label Chinese command unexpectedly succeeded"
  assert_eq "$pair_english_status" "$pair_chinese_status" \
    "$pair_label exit code" || return 1
  [ "$pair_english" != "$pair_chinese" ] || \
    harness_fail "$pair_label did not localize its human error"
  assert_contains "$pair_english" "$pair_stable_token" \
    "$pair_label English stable token" || return 1
  assert_contains "$pair_chinese" "$pair_stable_token" \
    "$pair_label Chinese stable token" || return 1
}

_i18n_case_runtime_project_and_cli() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-runtime-project
  user_home=$dir/user-home
  system_home=$dir/system-home
  workspace=$dir/workspace
  empty_dir=$dir/empty
  mkdir -p "$user_home" "$system_home" "$workspace" "$empty_dir"

  (
    cd "$workspace" || exit 1
    new_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" new runtime-en --flow) || exit 1
    new_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" new runtime-zh --flow) || exit 1
    assert_contains "$new_en" "created new flow project" \
      "project new English output" || exit 1
    assert_contains "$new_zh" "已创建新的 flow 项目" \
      "project new Chinese output" || exit 1

    cd runtime-en || exit 1
    check_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" check) || exit 1
    check_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" check) || exit 1
    assert_contains "$check_en" "[TAF] project ok: runtime-en" \
      "project check English output" || exit 1
    assert_contains "$check_zh" "[TAF] 项目检查通过：runtime-en" \
      "project check Chinese output" || exit 1
    assert_contains "$check_en" "runtime-en/" \
      "project check English stable path" || exit 1
    assert_contains "$check_zh" "runtime-en/" \
      "project check Chinese stable path" || exit 1

    compile_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" compile) || exit 1
    compile_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" compile) || exit 1
    assert_eq "$compile_en" "$compile_zh" \
      "project compile shell language invariant" || exit 1

    run_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" run) || exit 1
    run_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" run) || exit 1
    assert_eq "$run_en" "$run_zh" \
      "project app stdout language invariant" || exit 1
    assert_eq "<flow>[runtime-en: 0.1.0] Hello, World!" "$run_en" \
      "project app stdout remains raw" || exit 1

    build_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" build) || exit 1
    build_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" build) || exit 1
    assert_contains "$build_en" "[TAF] built command:" \
      "project build English output" || exit 1
    assert_contains "$build_zh" "[TAF] 命令已是最新：" \
      "project idempotent build Chinese output" || exit 1

    wrapper=target/taf-runtime-en-v0.1.0-r1
    assert_executable "$wrapper" || exit 1
    env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAF_HISTORY_MODE=sync \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$wrapper" >/dev/null || exit 1
    history_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" history --last 1) || exit 1
    history_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" history --last 1) || exit 1
    assert_contains "$history_en" "[TAF] history" \
      "history English output" || exit 1
    assert_contains "$history_zh" "[TAF] 执行历史" \
      "history Chinese output" || exit 1
    history_json_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" history --last 1 --json) || exit 1
    history_json_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" history --last 1 --json) || exit 1
    assert_eq "$history_json_en" "$history_json_zh" \
      "history JSON language invariant" || exit 1
    assert_contains "$history_json_en" "taf-runtime-en-v0.1.0-r1" \
      "history JSON preserves stable command" || exit 1

    rm src/main.taf
    _i18n_assert_failure_pair "$user_home" "$system_home" \
      "project missing main" "runtime-en/src/main.taf" \
      "$TAF_BIN" check || exit 1
  ) || return 1

  strict_commands='check build publish update search info install outdated upgrade prune uninstall list which doctor config history'
  for command in $strict_commands
  do
    _i18n_assert_failure_pair "$user_home" "$system_home" \
      "taf $command parser" "taf $command" \
      "$TAF_BIN" "$command" --i18n-invalid || return 1
  done
  _i18n_assert_failure_pair "$user_home" "$system_home" \
    "taf new missing name" "taf new" "$TAF_BIN" new || return 1
  (
    cd "$empty_dir" || exit 1
    _i18n_assert_failure_pair "$user_home" "$system_home" \
      "taf compile missing project" "taffish.toml" \
      "$TAF_BIN" compile || exit 1
    _i18n_assert_failure_pair "$user_home" "$system_home" \
      "taf run missing project" "taffish.toml" \
      "$TAF_BIN" run || exit 1
  )
}

_i18n_case_runtime_hub() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-runtime-hub
  user_home=$dir/user-home
  system_home=$dir/system-home
  mkdir -p "$user_home" "$system_home"

  (
    export TAFFISH_USER_HOME=$user_home
    export TAFFISH_SYSTEM_HOME=$system_home
    _taf_hub_prepare_index_fixture "$dir/fixture" || exit 1

    info_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      "$TAF_BIN" info multi-demo) || exit 1
    info_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      "$TAF_BIN" info multi-demo) || exit 1
    assert_contains "$info_en" "[TAF] app info: multi-demo" \
      "Hub info English output" || exit 1
    assert_contains "$info_zh" "[TAF] 应用信息：multi-demo" \
      "Hub info Chinese output" || exit 1
    assert_contains "$info_en" "taf-multi-demo" \
      "Hub info English stable command" || exit 1
    assert_contains "$info_zh" "taf-multi-demo" \
      "Hub info Chinese stable command" || exit 1
    info_json_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      "$TAF_BIN" info multi-demo --json) || exit 1
    info_json_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      "$TAF_BIN" info multi-demo --json) || exit 1
    assert_eq "$info_json_en" "$info_json_zh" \
      "Hub info JSON language invariant" || exit 1

    search_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      "$TAF_BIN" search multi) || exit 1
    search_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      "$TAF_BIN" search multi) || exit 1
    assert_contains "$search_en" "[TAF] search: multi" \
      "Hub search English output" || exit 1
    assert_contains "$search_zh" "[TAF] 搜索：multi" \
      "Hub search Chinese output" || exit 1

    list_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      "$TAF_BIN" list --online) || exit 1
    list_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      "$TAF_BIN" list --online) || exit 1
    assert_contains "$list_en" "[TAF] indexed apps" \
      "Hub list English output" || exit 1
    assert_contains "$list_zh" "[TAF] 索引中的应用" \
      "Hub list Chinese output" || exit 1

    _i18n_assert_failure_pair "$user_home" "$system_home" \
      "Hub missing target" "missing-i18n-app" \
      "$TAF_BIN" info missing-i18n-app || exit 1

    source_index=$dir/source-index.json
    cp "$user_home/index/current.json" "$source_index"
    update_en_home=$dir/update-en-home
    update_zh_home=$dir/update-zh-home
    mkdir -p "$update_en_home" "$update_zh_home"
    update_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$update_en_home" \
      TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" update --url "$source_index") || exit 1
    update_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$update_zh_home" \
      TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" update --url "$source_index") || exit 1
    assert_contains "$update_en" "[TAF] updated TAFFISH index" \
      "Hub update English output" || exit 1
    assert_contains "$update_zh" "[TAF] 已更新 TAFFISH 索引" \
      "Hub update Chinese output" || exit 1
    cmp "$update_en_home/index/current.json" \
      "$update_zh_home/index/current.json" >/dev/null || {
      printf 'localized Hub update changed current index bytes\n' >&2
      exit 1
    }
  )
}

_i18n_case_sparse_runtime_locales() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-sparse-runtime
  user_home=$dir/user-home
  system_home=$dir/system-home
  workspace=$dir/workspace
  mkdir -p \
    "$user_home/share/locales/es/help" \
    "$user_home/share/locales/pt" \
    "$user_home/share/locales/fr" \
    "$system_home" "$workspace"
  printf 'ES HELP ONLY\n' > "$user_home/share/locales/es/help/taf.txt"
  cat > "$user_home/share/locales/pt/messages.json" <<'EOF_PT_MESSAGES'
{"taf.project.check.header":"PT PROJECT {name}"}
EOF_PT_MESSAGES
  cat > "$user_home/share/locales/fr/messages.json" <<'EOF_FR_MESSAGES'
{"taf.project.check.header":"BAD {wrong}","taf.project.check.field.root":"RACINE"}
EOF_FR_MESSAGES

  (
    cd "$workspace" || exit 1
    env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" new sparse-flow --flow >/dev/null || exit 1
    cd sparse-flow || exit 1

    help_only=$(env TAFFISH_LANGUAGE=es TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" --help) || exit 1
    help_only_runtime=$(env TAFFISH_LANGUAGE=es TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" check) || exit 1
    assert_contains "$help_only" "ES HELP ONLY" \
      "help-only locale uses custom help" || exit 1
    assert_contains "$help_only_runtime" "[TAF] project ok: sparse-flow" \
      "help-only locale runtime falls back to English" || exit 1

    messages_only_help=$(env TAFFISH_LANGUAGE=pt TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" --help) || exit 1
    messages_only_runtime=$(env TAFFISH_LANGUAGE=pt TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" check) || exit 1
    assert_contains "$messages_only_help" "Usage:" \
      "messages-only locale help falls back to English" || exit 1
    assert_contains "$messages_only_runtime" "PT PROJECT sparse-flow" \
      "messages-only locale uses runtime catalog" || exit 1

    partial=$(env TAFFISH_LANGUAGE=fr TAFFISH_CONFIG= \
      TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
      "$TAF_BIN" check) || exit 1
    assert_contains "$partial" "[TAF] project ok: sparse-flow" \
      "bad runtime placeholder falls back for one key" || exit 1
    assert_contains "$partial" "RACINE" \
      "valid sibling runtime key remains active" || exit 1
    assert_not_contains "$partial" "BAD" \
      "bad placeholder translation is rejected" || exit 1
  )
}

_i18n_case_compiler_invariant() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-compiler
  user_home=$dir/user-home
  system_home=$dir/system-home
  mkdir -p "$user_home" "$system_home"
  cat > "$dir/invariant.taf" <<'EOF_INVARIANT_TAF'
ARGS
<(--/-n)name>
  world
RUN
<shell>
printf '%s\n' "hello, ::name::"
EOF_INVARIANT_TAF

  english=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" "$dir/invariant.taf" --name TAFFISH) || return 1
  chinese=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_BIN" "$dir/invariant.taf" --name TAFFISH) || return 1
  assert_eq "$english" "$chinese" \
    "generated shell is language invariant" || return 1
}

_i18n_mcp_requests() {
  cat <<'EOF_MCP_REQUESTS'
{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":2,"method":"resources/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"prompts/list","params":{}}
{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"taffish_get_config","arguments":{}}}
EOF_MCP_REQUESTS
}

_i18n_case_machine_interfaces_invariant() {
  dir=$TAFFISH_TEST_TMP_ROOT/i18n-machine
  user_home=$dir/user-home
  system_home=$dir/system-home
  os_home=$dir/os-home
  fake_bin=$dir/fake-bin
  mkdir -p "$user_home/index" "$system_home" "$os_home" "$fake_bin"
  cat > "$user_home/index/current.json" <<'EOF_EMPTY_INDEX'
{"schema_version":"taffish.index/v1","generated_at":"2026-01-01T00:00:00Z","packages":{},"commands":{}}
EOF_EMPTY_INDEX
  for backend in docker podman apptainer
  do
    cat > "$fake_bin/$backend" <<'EOF_FAKE_BACKEND'
#!/bin/sh
printf 'ready\n'
exit 0
EOF_FAKE_BACKEND
    chmod +x "$fake_bin/$backend"
  done

  doctor_en=$(env HOME="$os_home" PATH="$fake_bin:$PATH" \
    TAFFISH_LANGUAGE=en TAFFISH_CONFIG= TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" doctor --user --shell bash --json) || return 1
  doctor_zh=$(env HOME="$os_home" PATH="$fake_bin:$PATH" \
    TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= TAFFISH_USER_HOME="$user_home" \
    TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" doctor --user --shell bash --json) || return 1
  assert_eq "$doctor_en" "$doctor_zh" "doctor JSON language invariant" || return 1
  assert_contains "$doctor_zh" '"schema_version": "taffish.doctor/v1"' \
    "doctor JSON schema remains stable" || return 1

  history_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" history --json) || return 1
  history_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" history --json) || return 1
  assert_eq "$history_en" "$history_zh" "history JSON language invariant" || return 1

  index_en=$(env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" list --online --json) || return 1
  index_zh=$(env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAF_BIN" list --online --json) || return 1
  assert_eq "$index_en" "$index_zh" "index JSON language invariant" || return 1

  mcp_en=$(_i18n_mcp_requests | env TAFFISH_LANGUAGE=en TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" 2>/dev/null) || return 1
  mcp_zh=$(_i18n_mcp_requests | env TAFFISH_LANGUAGE=zh TAFFISH_CONFIG= \
    TAFFISH_USER_HOME="$user_home" TAFFISH_SYSTEM_HOME="$system_home" \
    "$TAFFISH_MCP_BIN" 2>/dev/null) || return 1
  assert_eq "$mcp_en" "$mcp_zh" \
    "MCP tools resources prompts and config are language invariant" || return 1
  assert_contains "$mcp_zh" '"taffish_get_config"' \
    "MCP machine tool remains available" || return 1
  assert_not_contains "$mcp_zh" '"taffish_config_language"' \
    "MCP does not expose language mutation" || return 1
  assert_not_contains "$mcp_zh" '"taffish_set_language"' \
    "MCP does not expose config mutation alias" || return 1
}

run_i18n_conformance() {
  run_case "i18n/builtin-help-errors" _i18n_case_builtin_help_and_errors
  run_case "i18n/unicode-stdio-pipes" _i18n_case_unicode_stdio_pipes
  run_case "i18n/resolution-priority" _i18n_case_resolution_priority
  run_case "i18n/external-locale-safety" _i18n_case_external_locale_safety
  run_case "i18n/human-config-doctor" _i18n_case_human_config_and_doctor
  run_case "i18n/language-management" _i18n_case_language_management
  run_case "i18n/runtime-project-cli" _i18n_case_runtime_project_and_cli
  run_case "i18n/runtime-hub" _i18n_case_runtime_hub
  run_case "i18n/sparse-runtime-locales" _i18n_case_sparse_runtime_locales
  run_case "i18n/compiler-invariant" _i18n_case_compiler_invariant
  run_case "i18n/machine-interfaces-invariant" \
    _i18n_case_machine_interfaces_invariant
}
