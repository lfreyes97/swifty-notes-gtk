#!/usr/bin/env bash
# Run every test in `MarkdownPreviewWidgetXCTests` in its own `swift test`
# invocation. On macOS the suite has a cumulative-state issue (async remote
# image loaders + GLib idle callbacks left over between tests) that crashes
# the xctest process before the suite finishes, even though each individual
# test passes. Process-per-test isolation is the workaround.
#
# By default the suite is gated by `SWIFTY_NOTES_RUN_PREVIEW_TESTS`; we set
# it here so the suite's `setUpWithError` doesn't auto-skip.
#
# Usage:
#   scripts/test-macos-preview.sh
#   FILTER='preview_code_block' scripts/test-macos-preview.sh    # only matching tests
#
# Exit status: non-zero if any individual test failed.

set -uo pipefail

cd "$(dirname "$0")/.."

export SWIFTY_NOTES_RUN_PREVIEW_TESTS=1
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-/opt/homebrew/share}"

# Build once and enumerate every MarkdownPreviewWidgetXCTests case via
# `swift test list`. Run each case in its own `swift test --filter`.
echo "Discovering tests…"
tests=$(
  swift test list 2>/dev/null \
    | awk -F/ '/^SwiftyNotesTests\.MarkdownPreviewWidgetXCTests\//{print $2}'
)

if [[ -z "$tests" ]]; then
  echo "No MarkdownPreviewWidgetXCTests tests discovered." >&2
  exit 1
fi

filter="${FILTER:-}"
total=0
passed=0
failed=()

while IFS= read -r test; do
  if [[ -n "$filter" && "$test" != *"$filter"* ]]; then
    continue
  fi
  total=$((total + 1))
  printf '[%2d] %-90s ' "$total" "$test"
  if swift test --no-parallel \
       --filter "MarkdownPreviewWidgetXCTests/$test" >/dev/null 2>&1; then
    echo "PASS"
    passed=$((passed + 1))
  else
    echo "FAIL"
    failed+=("$test")
  fi
done <<<"$tests"

echo
echo "Summary: $passed/$total passed"
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "Failed tests:"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
