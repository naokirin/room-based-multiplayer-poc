#!/usr/bin/env bash
# Format edited Ruby files with RuboCop (auto-correct) when available.
# Receives JSON on stdin from Cursor's afterFileEdit hook; extracts file_path and runs rubocop -a.
set -euo pipefail
input=$(cat)
file_path=$(printf '%s' "$input" | ruby -rjson -e 'puts JSON.parse(STDIN.read).dig("file_path")' 2>/dev/null) || exit 0
if [[ -z "$file_path" || "$file_path" != *.rb || ! -f "$file_path" ]]; then
  exit 0
fi
# Run from project root (parent of .cursor)
root="${CURSOR_PROJECT_DIR:-.}"
if command -v bundle &>/dev/null && \
   [[ -f "$root/Gemfile" ]] && \
   bundle show rubocop &>/dev/null 2>&1; then
  (cd "$root" && bundle exec rubocop -a --format simple "$file_path" 2>/dev/null) || true
fi
exit 0
