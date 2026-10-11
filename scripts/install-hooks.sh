#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
existing="$(git config --get core.hooksPath || true)"
if [[ -n "$existing" && "$existing" != .githooks ]]; then
    printf 'Existing hooksPath is %s. Merge the pre-push hook there instead of replacing it.\n' "$existing" >&2
    exit 1
fi
if [[ -f .git/hooks/pre-push && -z "$existing" ]]; then
    printf 'An existing .git/hooks/pre-push hook needs to be merged manually.\n' >&2
    exit 1
fi
git config --local core.hooksPath .githooks
printf 'Pre-push tests enabled for this checkout.\n'
