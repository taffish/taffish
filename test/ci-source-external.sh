#!/bin/bash
# Check all three executables from a single development build.
set -euo pipefail

bin=${1:?usage: ci-source-external.sh BUILD_BIN_DIR}
log=${RUNNER_TEMP:?set RUNNER_TEMP to the CI scratch directory}/source-external.log
unset TAFFISH_TEST_FILTER
test/run-tests.sh --taf "$bin/taf" --taffish "$bin/taffish" --taffish-mcp "$bin/taffish-mcp" \
  2>&1 | tee "$log"

# Only signed release payloads can exercise the installer's release signature.
awk '/^\[SKIP\] / && $0 != "[SKIP] installer/gpg-verification" { bad=1 } END { exit bad }' "$log"
