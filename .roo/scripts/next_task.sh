#!/bin/bash

set -e

ROO="$(cd "$(dirname "$0")/.." && pwd)"
BACKLOG="$ROO/tasks/backlog.md"
CURRENT="$ROO/tasks/current_task.md"

TASK=""
while IFS= read -r line || [ -n "$line" ]; do
  if [[ "$line" =~ ^T[0-9]+\.[0-9]+ ]]; then
    TASK="$line"
    break
  fi
done < "$BACKLOG"

if [ -z "$TASK" ]; then
  echo "No tasks left"
  exit 0
fi

found=0
while IFS= read -r line || [ -n "$line" ]; do
  if [ "$found" -eq 0 ] && [ "$line" = "$TASK" ]; then
    found=1
    continue
  fi
  printf '%s\n' "$line"
done < "$BACKLOG" > "$BACKLOG.tmp"
mv "$BACKLOG.tmp" "$BACKLOG"

echo "$TASK" > "$CURRENT"

echo "Loaded task: $TASK"
