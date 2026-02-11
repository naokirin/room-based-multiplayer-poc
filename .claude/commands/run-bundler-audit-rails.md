---
description: Scan gem dependencies for known vulnerabilities
disable-model-invocation: true
---

# Run Bundler Audit

Scan gem dependencies for known security vulnerabilities: $ARGUMENTS

## Instructions

1. Check whether `bundler-audit` is available (`Gemfile` has `bundler-audit`; or `bundle-audit` is installed globally).
2. Update the advisory database: `bundle audit update`.
3. Run the audit: `bundle audit check`.
4. Review each reported vulnerability:
   - **Gem name and version**: which dependency is affected.
   - **Advisory / CVE**: the vulnerability identifier.
   - **Patched versions**: which versions resolve the issue.
5. For each vulnerability, propose the fix:
   - If a patched version exists, update the gem (`bundle update <gem>`).
   - If no patch is available, evaluate whether the vulnerability affects this project and suggest workarounds or alternative gems.
6. After updates, run the test suite (`bundle exec rspec` or `bin/rails test`) to ensure nothing broke.

If the audit reports no vulnerabilities, confirm the scan passed.
