#!/usr/bin/env bash
# Format edited TypeScript/JavaScript files with Biome when available.
# Receives JSON on stdin from Cursor's afterFileEdit hook; extracts file_path and runs Biome format.
set -euo pipefail
input=$(cat)

# Extract file_path from JSON using jq (preferred) or python3 as fallback
if command -v jq &>/dev/null; then
  file_path=$(printf '%s' "$input" | jq -r '.file_path // empty' 2>/dev/null) || exit 0
elif command -v python3 &>/dev/null; then
  file_path=$(printf '%s' "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null) || exit 0
else
  exit 0
fi

if [[ -z "$file_path" ]]; then
  exit 0
fi
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
  *) exit 0 ;;
esac
[[ -f "$file_path" ]] || exit 0

root="${CURSOR_PROJECT_DIR:-.}"
if [[ -f "$root/package.json" ]] && command -v npx &>/dev/null; then
  (cd "$root" && npx biome format --write "$file_path" 2>/dev/null) || true
fi
exit 0
