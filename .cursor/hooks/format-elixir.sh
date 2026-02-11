#!/usr/bin/env bash
# Format edited Elixir/Phoenix files with mix format when available.
# Receives JSON on stdin from Cursor's afterFileEdit hook; extracts file_path and runs mix format.
set -euo pipefail
input=$(cat)

# Extract file_path from JSON using jq (preferred) or python3 as fallback
if command -v jq &>/dev/null; then
  file_path=$(printf '%s' "$input" | jq -r '.file_path // empty' 2>/dev/null) || exit 0
elif command -v python3 &>/dev/null; then
  file_path=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null) || exit 0
else
  # No JSON parser available; skip formatting
  exit 0
fi

if [[ -z "$file_path" ]]; then
  exit 0
fi
case "$file_path" in
  *.ex|*.exs) ;;
  *) exit 0 ;;
esac
[[ -f "$file_path" ]] || exit 0

root="${CURSOR_PROJECT_DIR:-.}"
if command -v mix &>/dev/null && [[ -f "$root/mix.exs" ]]; then
  (cd "$root" && mix format "$file_path" 2>/dev/null) || true
fi
exit 0
