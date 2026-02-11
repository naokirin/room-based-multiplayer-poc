#!/usr/bin/env bash
# Format edited TypeScript/JavaScript files with Biome when available.
# Triggered by Claude Code PostToolUse hook for Edit/Write tools.
# Receives JSON on stdin with tool_input.file_path.
set -euo pipefail

input=$(cat)

# Extract file_path: Claude Code uses tool_input.file_path; Cursor uses file_path at top level
if command -v jq &>/dev/null; then
  file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .file_path // empty' 2>/dev/null) || exit 0
elif command -v python3 &>/dev/null; then
  file_path=$(printf '%s' "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    file_path = d.get('tool_input', {}).get('file_path') or d.get('file_path', '')
    print(file_path or '')
except Exception:
    print('')
" 2>/dev/null) || exit 0
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

root="${CLAUDE_PROJECT_DIR:-.}"
if [[ -f "$root/package.json" ]]; then
  if command -v npx &>/dev/null; then
    (cd "$root" && npx biome format --write "$file_path" 2>/dev/null) || true
  fi
fi
exit 0
