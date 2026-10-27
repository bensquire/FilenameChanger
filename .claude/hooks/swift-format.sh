#!/usr/bin/env bash
# PostToolUse hook: format an edited Swift file against .swift-format, then list
# the lines still over its `lineLength`. One script, not two, because Claude
# Code runs a matcher's hooks in parallel, and a separate measuring hook could
# read the file before formatting had finished.
#
# swift-format only breaks what it can: a long string or doc comment stays
# long, and those are the lines an agent writes. They are reported with their
# widths and the hook exits 2, which is advice: it never blocks the edit.
#
# Adapted from AssemblyAI/blurt's hooks (MIT), by way of Prospect and ImageAlpha.
set -euo pipefail

file="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
  2>/dev/null || true)"
case "$file" in
  *.swift) [ -f "$file" ] || exit 0 ;;
  *) exit 0 ;;
esac

config="${CLAUDE_PROJECT_DIR:-.}/.swift-format"
# `swift format`, as the Makefile runs it; absent a toolchain, skip.
swift format format -i --configuration "$config" "$file" >/dev/null 2>&1 || true

# Counted in characters, not bytes: these sources carry em dashes, ellipses and
# curly quotes, and a byte count would flag a line a few characters short.
findings="$(
  python3 -c '
import json, sys
try:
    limit = int(json.load(open(sys.argv[2])).get("lineLength", 110))
except (OSError, ValueError):
    limit = 110
long = [(n, len(l.rstrip("\n"))) for n, l in enumerate(open(sys.argv[1], encoding="utf-8", errors="replace"), 1)]
long = [(n, w) for n, w in long if w > limit]
if long:
    print(f"Lines over {limit} columns in {sys.argv[1]}:")
    for n, w in long:
        print(f"  {n}: {w} columns")
    print("  Reflow them: swift-format could not break these on its own.")
' "$file" "$config" 2>/dev/null || true
)"

if [ -n "$findings" ]; then
  printf '%s\n' "$findings" >&2
  exit 2
fi
exit 0
