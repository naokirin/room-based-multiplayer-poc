---
description: Run Brakeman security scan and review warnings
disable-model-invocation: true
argument-hint: "[--only-files path]"
---

# Run Brakeman Security Scan

Run Brakeman and review security warnings: $ARGUMENTS

## Instructions

1. Check whether the project uses Brakeman (`Gemfile` has `brakeman`; or `brakeman` is installed globally).
2. Run `bundle exec brakeman` (or `brakeman` if global). Add `--no-pager` for non-interactive output.
3. Review the warnings by category:
   - **SQL Injection**: string interpolation in queries, unsafe `find_by_sql` / `execute`.
   - **Cross-Site Scripting (XSS)**: unescaped output (`raw`, `html_safe`) without sanitization.
   - **Mass Assignment**: missing or overly permissive strong parameters.
   - **CSRF**: missing `protect_from_forgery` or skipped verification without justification.
   - **Open Redirect**: unvalidated redirect URLs from user input.
   - **File Access**: user-controlled paths in `send_file` / `File.read`.
4. For each warning, cite the file, line, and confidence level. Propose a concrete fix.
5. If no Brakeman warnings are found, confirm the scan passed.

If the user specified files or a scope, note that Brakeman scans the entire app by default. Use `--only-files` to limit scope when appropriate.
