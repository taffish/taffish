#!/bin/bash
# Verify the published layout for the source version and prepare native files for the external suite.
set -euo pipefail

work=${1:?usage: ci-release-payloads.sh NEW_OUTPUT_DIR}
mkdir -m 700 "$work"
work=$(cd "$work" && pwd -P)
root=$(cd "$(dirname "$0")/.." && pwd -P)
version=$(sed -n 's/.*:version "\([^"]*\)".*/\1/p' "$root/taffish.asd" | head -n 1)
release_pattern='^([0-9]+)\.([0-9]+)\.[0-9]+(-[A-Za-z0-9.-]+)?(\+[A-Za-z0-9.-]+)?$'
if [[ ! $version =~ $release_pattern ]]; then
  echo "Unsupported release version in taffish.asd: $version" >&2
  exit 1
fi
legacy=false
if (( 10#${BASH_REMATCH[1]} == 0 && 10#${BASH_REMATCH[2]} < 12 )); then
  legacy=true
  cd "$root/target"
else
  cd "$root/target/packages-$version"
fi

for installer in install-taffish.sh install-taffish.gitee.sh; do
  plan=$("$root/install/$installer" --dry-run)
  default_tag=$(printf '%s\n' "$plan" | awk '$1=="source" && $2=="tag" && $3==":" {print $4}')
  if [[ $default_tag != "v$version" ]]; then
    echo "$installer defaults to $default_tag; expected v$version from taffish.asd" >&2
    exit 1
  fi
done

# Use the same pinned primary key as the production installer.
expected=$(sed -n 's/^TAFFISH_RELEASE_KEY_FINGERPRINT=\([A-F0-9]*\)$/\1/p' "$root/install/install-taffish.sh")
[[ $expected =~ ^[A-F0-9]{40}$ ]]
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
fingerprints=$(gpg --batch --with-colons --show-keys TAFFISH-RELEASE-KEY.asc |
  awk -F: '$1=="pub" {primary=1} $1=="fpr" && primary {print $10; primary=0}')
[[ $fingerprints == "$expected" ]]
keyring=$work/release.gpg
gpg --batch --dearmor --output "$keyring" TAFFISH-RELEASE-KEY.asc
if "$legacy"; then
  gpgv --keyring "$keyring" SHA256SUMS.asc SHA256SUMS
  shasum -a 256 -c SHA256SUMS
  ln -s "$root/target" "$work/target"
  exit 0
fi

mac_archive="taffish-$version-darwin-arm64.tar.xz"
linux_archive="taffish-$version-linux-amd64.tar.gz"
gpgv --keyring "$keyring" ARCHIVE-SHA256SUMS.asc ARCHIVE-SHA256SUMS
# Require both architectures, each exactly once, before using any archive.
awk -v mac="$mac_archive" -v linux="$linux_archive" '
  { sub(/^\*/, "", $2) }
  NF != 2 || ($2 != mac && $2 != linux) { exit 1 }
  { count[$2]++ }
  END { if (count[mac] != 1 || count[linux] != 1) exit 1 }
' ARCHIVE-SHA256SUMS
shasum -a 256 -c ARCHIVE-SHA256SUMS

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) platform=darwin-arm64; archive=$mac_archive ;;
  Linux/x86_64) platform=linux-amd64; archive=$linux_archive ;;
  *) echo 'Unsupported release CI platform' >&2; exit 1 ;;
esac

mkdir "$work/home"
HOME="$work/home" "$root/install/install-taffish.sh" --user --prefix "$work/installed" \
  --local --accept-runtime-license --version "$version" --verify gpg --config-profile none --no-doctor
receipt=$work/installed/share/taffish/install-receipt.toml
grep -Fx 'verification = "gpg"' "$receipt"
grep -Fx 'archive_verification = "gpg"' "$receipt"
grep -Fx "archive_asset = \"$archive\"" "$receipt"
grep -Fx "archive_sha256 = \"$(shasum -a 256 "$archive" | awk '{print $1}')\"" "$receipt"
grep -Fx "version = \"$version\"" "$receipt"

license_dir=$work/installed/share/taffish/share/licenses
cmp "$root/LICENSE" "$license_dir/TAFFISH-LICENSE.txt"
cmp "$root/vendor/han/LICENSE" "$license_dir/HAN-LICENSE.txt"
case "$platform" in
  darwin-arm64) cmp "$root/licenses/SBCL-NOTICES.txt" "$license_dir/SBCL-NOTICES.txt" ;;
  linux-amd64)
    cmp "$root/licenses/LISPWORKS-RUNTIME.txt" "$license_dir/LISPWORKS-RUNTIME.txt"
    grep -Fx 'runtime_license_acceptance = "flag"' "$receipt"
    grep -Fx "runtime_license_sha256 = \"$(shasum -a 256 "$license_dir/LISPWORKS-RUNTIME.txt" | awk '{print $1}')\"" "$receipt"
    ;;
esac

# External tests need the signed inner manifest alongside the exact bytes installed above.
# The installer has already verified both signatures and validated this native archive.
tar -xf "$archive" -C "$work" target/SHA256SUMS target/SHA256SUMS.asc target/TAFFISH-RELEASE-KEY.asc
for program in taf taffish taffish-mcp; do
  exe=$work/installed/bin/$program
  reported=$("$exe" --version | awk 'NR == 1 && NF == 2 {print $1, $2}')
  [[ $reported == "$program $version" ]]
  if [[ $platform == darwin-arm64 ]]; then
    lipo -verify_arch arm64 "$exe"
    otool -L "$exe" | awk '
      NR > 1 && $1 !~ /^\/(usr\/lib|System\/Library)\// {print "Unexpected runtime dependency:", $0; bad=1}
      END {exit (bad || NR < 2)}
    '
  fi
  ln "$exe" "$work/target/$program-$platform-$version"
done
