# Testing FinanceTracker

## Before pushing

Connect and unlock your iPhone, enable Developer Mode, and trust the Mac. The
project currently requires iOS 27+ and Xcode 27. The app and test target use the
same development team; configure your signing account in Xcode if necessary.

From the repository root:

```sh
./scripts/pre-push-check.sh
```

This detects a connected physical device, runs all unit and integration tests,
and checks that the Release app compiles. It never silently switches to a
simulator. Incremental builds reuse `DerivedData/Tests`.

To test without the Release build:

```sh
./scripts/test.sh                  # all tests on a connected device
./scripts/test.sh --unit           # unit tests only
./scripts/test.sh --integration    # integration tests only
./scripts/test.sh --simulator      # explicitly use a simulator
```

If multiple devices are connected, select one explicitly:

```sh
TEST_DESTINATION='platform=iOS,id=YOUR_DEVICE_UDID' ./scripts/test.sh
```

Set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` if your selected
command-line tools point to a different Xcode. The scripts automatically handle
a CommandLineTools-only selection when Xcode is installed in its usual location.

A physical-device test run builds and installs the current Debug app and its test
bundle. During testing the app uses an in-memory store, and persistence tests use
isolated in-memory or temporary stores. They never edit your saved receipts.
Afterward, run the app normally from Xcode to use your existing persistent store.

## Run in Xcode

Open `FinanceTracker.xcodeproj`, select the shared **FinanceTracker** scheme and
your connected iPhone as the destination, then choose **Product > Test** (`Cmd+U`).
The Test navigator (`Cmd+6`) lets you run individual test classes or methods.
The scheme supplies `FINANCE_TRACKER_TESTING=1` automatically; keep this setting
so the hosted app uses isolated storage.

## Automatic pre-push checks

Enable the version-controlled hook once per checkout:

```sh
./scripts/install-hooks.sh
```

`git push` then runs the full check and stops if anything fails. Commit or stash
pending changes first: the hook requires a clean tree and only validates the
checked-out commit being pushed. This prevents a green result from uncommitted
fixes masking a broken commit. The installer preserves existing custom hooks by
refusing to replace them; merge hooks manually if it reports a conflict.

To remove this checkout's hook configuration:

```sh
git config --local --unset core.hooksPath
```

## GitHub Actions

`.github/workflows/tests.yml` runs the same full check on pushes, pull requests,
and manual dispatches. CI explicitly uses an iOS simulator on GitHub's
[`xcode-27` runner](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md),
because GitHub cannot access the iPhone attached to your Mac. The runner is
currently in public preview; its availability and billing depend on your GitHub
account. No Apple signing credentials are required for CI.

Commit and push the workflow to activate it. In GitHub, open **Actions > iOS
checks** to inspect a run. For merge protection, configure a branch ruleset to
require the **Unit and integration tests** status check after its first run.
Local hooks can be bypassed, so required checks provide the server-side gate.
Repository rules are not changed by the scripts.

## Results and coverage

Each run writes `.test-results/<timestamp>-<pid>/` with an Xcode result bundle,
log, coverage JSON, destination, commit ID, and working-tree state. The directory
is ignored by Git. `.test-results/latest` points to the newest run.

Open `.test-results/latest/Tests.xcresult` in Xcode to see test results and app
coverage. GitHub uploads the result directory as an artifact for 14 days, even
when a test fails. Test failures are not automatically retried.

## Coverage and limits

- Unit: integer-cent parsing, invalid money formats, totals, missing fields,
  zero versus unknown tax, weighted quantities, draft correction, redaction,
  OCR row ordering, and item/price alignment.
- Integration: real Apple Vision on a synthetic receipt image, invalid/blank
  images, OCR cancellation, OCR-to-AI handoff and error propagation, cancellation
  before/after AI, review-and-save, warnings requiring confirmation, disk reload,
  relationships, cascade deletion, and migration from the original receipt schema.
- Automated pipeline tests inject fixed AI responses. They verify orchestration
  and saving, not the accuracy of Apple's language model. Real Apple Intelligence
  extraction remains a device check with representative receipts, particularly
  faded photos, logo-only headers, taxes, discounts, and long receipts.
- These are unit/integration tests, not UI automation. They do not automate Photos
  permissions, picker gestures, navigation, or editing controls. Check import,
  review, cancel, save, and unavailable-AI states interactively before release.

Coverage is recorded rather than enforcing an arbitrary percentage. Add tests
for each bug fixed and each new behavior; prioritize calculations, persistence,
and error handling over view boilerplate.
