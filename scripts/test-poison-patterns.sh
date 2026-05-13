#!/usr/bin/env bash
# Compile each poison pattern and verify it fails with the expected error.
#
# Poison patterns live in src/poison/<name>/ alongside an expected_error.txt.
# Each pattern is a Nargo contract package expected to fail nargo check.
#
# The expected_error.txt contains a substring that MUST appear in the compiler
# output when the package fails. This verifies the right constraint is being
# violated, not some unrelated error.
#
# Nargo anchors workspace discovery to the git root, so each poison package
# must be temporarily added to the root Nargo.toml workspace members before
# nargo can find it. This script patches and restores atomically.
#
# Usage: ./scripts/test-poison-patterns.sh [pattern_name]
#   No args: test all patterns in src/poison/
#   pattern_name: test only src/poison/<pattern_name>/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
POISON_DIR="$REPO_ROOT/src/poison"
ROOT_NARGO="$REPO_ROOT/Nargo.toml"
FILTER="${1:-}"

PASS=0
FAIL=0

# --- Workspace patch helpers -------------------------------------------------

original_nargo=""

patch_workspace() {
    local rel_path="$1"
    original_nargo=$(cat "$ROOT_NARGO")
    # Insert the path as the first member so it's easy to remove
    python3 - "$ROOT_NARGO" "$rel_path" << 'PY'
import sys, re
path, rel = sys.argv[1], sys.argv[2]
content = open(path).read()
content = re.sub(r'(members\s*=\s*\[)', r'\1\n  "' + rel + r'",', content, count=1)
open(path, 'w').write(content)
PY
}

restore_workspace() {
    if [ -n "$original_nargo" ]; then
        printf '%s' "$original_nargo" > "$ROOT_NARGO"
        original_nargo=""
    fi
}

# Always restore on exit, including on error or Ctrl-C
trap restore_workspace EXIT

# --- Pattern runner ----------------------------------------------------------

run_pattern() {
    local pkg_dir="$1"
    local pkg_name
    pkg_name=$(grep '^name' "$pkg_dir/Nargo.toml" | sed 's/.*= *"\([^"]*\)".*/\1/')
    local rel_path="src/poison/$(basename "$pkg_dir")"
    local expected_error_file="$pkg_dir/expected_error.txt"

    echo ""
    echo "── poison: $pkg_name ────────────────────────────────────────"

    # Temporarily add to root workspace
    patch_workspace "$rel_path"

    # Compile — must fail (either non-zero exit or "error:" in output)
    # Nargo comptime assert(false) prints "error:" but exits 0 — we accept both.
    local output
    local exit_code=0
    output=$(cd "$REPO_ROOT" && nargo check --package "$pkg_name" 2>&1) || exit_code=$?
    local has_error_line=0
    printf '%s\n' "$output" | grep -q '^error:' && has_error_line=1 || true

    restore_workspace

    if [ "$exit_code" -eq 0 ] && [ "$has_error_line" -eq 0 ]; then
        echo "  FAIL: compilation succeeded with no errors (expected failure)"
        FAIL=$((FAIL + 1))
        return
    fi

    # Verify expected error substring
    if [ -f "$expected_error_file" ]; then
        local expected
        expected=$(cat "$expected_error_file")
        if printf '%s' "$output" | grep -qF "$expected"; then
            echo "  PASS: failed with expected error"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: failed but error does not match expected_error.txt"
            echo "  Expected substring: $(head -1 "$expected_error_file")"
            echo "  Actual output (last 10 lines):"
            printf '%s\n' "$output" | tail -10 | sed 's/^/    /'
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  PASS: failed (no expected_error.txt — any error accepted)"
        PASS=$((PASS + 1))
    fi
}

# --- Main --------------------------------------------------------------------

echo "Poison pattern tests"
echo "Poison dir: $POISON_DIR"

found=0
for pkg_dir in "$POISON_DIR"/*/; do
    [ -d "$pkg_dir" ] || continue
    [ -f "$pkg_dir/Nargo.toml" ] || continue

    pkg_name=$(basename "$pkg_dir")
    if [ -n "$FILTER" ] && [ "$pkg_name" != "$FILTER" ]; then
        continue
    fi

    found=$((found + 1))
    run_pattern "$pkg_dir"
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $found patterns)"
echo ""

if [ "$found" -eq 0 ]; then
    echo "No poison patterns found in $POISON_DIR"
    exit 1
fi

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
