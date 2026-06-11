#!/bin/bash
# Append a top-level index line to done.md after Reviewer APPROVE.
# Requires .roo/tasks/completed/{TASK_ID}.md to exist (written by Builder).

set -e

ROO="$(cd "$(dirname "$0")/.." && pwd)"
CURRENT="$ROO/tasks/current_task.md"
DONE="$ROO/tasks/done.md"
COMPLETED_DIR="$ROO/tasks/completed"

task_line() {
  grep -m1 -E '^T[0-9]+\.[0-9]+ ' "$CURRENT" 2>/dev/null || head -n 1 "$CURRENT"
}

TASK_LINE="$(task_line)"
TASK_ID="$(echo "$TASK_LINE" | grep -oE '^T[0-9]+\.[0-9]+' || true)"

if [ -z "$TASK_ID" ]; then
  echo "No task ID (T{n}.{m}) found in $CURRENT" >&2
  exit 1
fi

AUDIT="$COMPLETED_DIR/${TASK_ID}.md"
if [ ! -f "$AUDIT" ]; then
  echo "Missing audit log: $AUDIT (Builder should create this before REVIEW)" >&2
  exit 1
fi

DATE="$(date +%Y-%m-%d)"
SHORT="$(echo "$TASK_LINE" | sed -E "s/^${TASK_ID} //" | sed 's/ —.*//')"

echo "- ${TASK_ID} ${SHORT} — [completed/${TASK_ID}.md](completed/${TASK_ID}.md) — ${DATE}" >> "$DONE"
echo "Indexed ${TASK_ID} in done.md"
