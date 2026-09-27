#!/bin/bash
# Stop hook: blocks Claude from finishing if code changed but CONTEXT.md / docs/FUNCTIONS.md weren't updated.

input=$(cat)
echo "$input" | grep -q '"stop_hook_active": *true' && exit 0   # prevent loops
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

changed=$(git status --porcelain -uall | awk '{print $NF}')
[ -z "$changed" ] && exit 0                                     # nothing changed
echo "$changed" | grep -Evq '\.md$' || exit 0                   # only docs changed

missing=""
echo "$changed" | grep -qx 'CONTEXT.md' || missing="CONTEXT.md"
# FUNCTIONS.md lists functions, so only require it when Dart code under lib/ changed.
if echo "$changed" | grep -q '^lib/.*\.dart$'; then
  echo "$changed" | grep -qx 'docs/FUNCTIONS.md' || missing="$missing docs/FUNCTIONS.md"
fi
[ -z "$missing" ] && exit 0

echo "Code changed but not updated: $missing. Call the doc-keeper subagent, then finish." >&2
exit 2
