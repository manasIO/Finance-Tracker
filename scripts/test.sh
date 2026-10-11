#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Keep the user's selected Xcode; recover from a CommandLineTools-only setup.
if [[ -z "${DEVELOPER_DIR:-}" ]] && [[ "$(xcode-select -p)" == */CommandLineTools ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mode=--device
suite=all
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device|--simulator) mode="$1" ;;
        --unit) suite=unit ;;
        --integration) suite=integration ;;
        --help)
            printf 'Usage: ./scripts/test.sh [--device|--simulator] [--unit|--integration]\nDefaults to all tests on one connected iOS 27+ device.\nOverride with TEST_DESTINATION, DEVELOPER_DIR, or DERIVED_DATA_PATH.\n'
            exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

destination="${TEST_DESTINATION:-}"
if [[ -z "$destination" ]]; then
    destination="$(python3 scripts/select-test-destination.py "$mode")"
fi
results="$(pwd)/.test-results/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$results"
ln -sfn "$(basename "$results")" .test-results/latest
printf 'Testing on %s\nResults: %s\n' "$destination" "$results"
printf '%s\n' "$destination" > "$results/destination.txt"
git rev-parse HEAD > "$results/commit.txt"
git status --short > "$results/working-tree.txt"

options=(-parallel-testing-enabled NO)
if [[ "$destination" == platform=iOS\ Simulator,* ]]; then
    options+=(CODE_SIGNING_ALLOWED=NO)
fi
if [[ "$suite" == unit ]]; then
    for name in ReceiptValidatorTests ReceiptImportDraftTests ReceiptRedactorTests ReceiptOCRLayoutTests SpendingSummaryTests ReceiptPhotoEncoderTests; do
        options+=("-only-testing:FinanceTrackerTests/$name")
    done
elif [[ "$suite" == integration ]]; then
    for name in ReceiptImportServiceTests ReceiptOCRServiceTests ReceiptPersistenceTests ReceiptMigrationTests DashboardPersistenceTests; do
        options+=("-only-testing:FinanceTrackerTests/$name")
    done
fi

# No retries: a failure must block a push, not be hidden by a passing rerun.
xcodebuild -quiet -project FinanceTracker.xcodeproj -scheme FinanceTracker \
    -configuration Debug -destination "$destination" -destination-timeout 30 \
    -derivedDataPath "${DERIVED_DATA_PATH:-$(pwd)/DerivedData/Tests}" \
    -resultBundlePath "$results/Tests.xcresult" -enableCodeCoverage YES \
    "${options[@]}" test 2>&1 | tee "$results/test.log"
xcrun xcresulttool get test-results summary --path "$results/Tests.xcresult" > "$results/summary.json"
python3 - "$results/summary.json" <<'PY'
import json
import sys
with open(sys.argv[1]) as file:
    summary = json.load(file)
count = summary.get("totalTestCount", 0)
if count == 0 or summary.get("passedTests", 0) != count:
    sys.exit("The test report did not contain a complete passing suite. Inspect summary.json.")
print(f"Verified {count} passed tests with no failures or skips.")
PY
xcrun xccov view --report --json "$results/Tests.xcresult" > "$results/coverage.json"
printf 'All selected tests passed. Open %s in Xcode for results and coverage.\n' "$results/Tests.xcresult"
