#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ "$(xcode-select -p)" == */CommandLineTools ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
./scripts/test.sh "$@"
# Check customer compilation as well as Debug tests.
xcodebuild -quiet -project FinanceTracker.xcodeproj -scheme FinanceTracker \
    -configuration Release -destination 'generic/platform=iOS' \
    -derivedDataPath "${DERIVED_DATA_PATH:-$(pwd)/DerivedData/Tests}" \
    CODE_SIGNING_ALLOWED=NO build
