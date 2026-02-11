#!/usr/bin/env bash
# Format edited Ruby files with RuboCop (auto-correct) when available.
# Triggered by Claude Code PostToolUse hook for Edit/Write tools.
# Receives JSON on stdin with tool_input.file_path.
set -euo pipefail

# Read hook context from stdin
input=$(cat)

# Extract file_path from tool_input
file_path=$(printf '%s' "$input" | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  puts data.dig("tool_input", "file_path").to_s
' 2>/dev/null) || exit 0

# Only process .rb files that exist
if [[ -z "$file_path" || "$file_path" != *.rb || ! -f "$file_path" ]]; then
  exit 0
fi

# Run RuboCop auto-correct if available via Bundler
root="${CLAUDE_PROJECT_DIR:-.}"
if command -v bundle &>/dev/null && \
   [[ -f "$root/Gemfile" ]] && \
   bundle show rubocop &>/dev/null 2>&1; then
  (cd "$root" && bundle exec rubocop -a --format simple "$file_path" 2>/dev/null) || true
fi

exit 0
