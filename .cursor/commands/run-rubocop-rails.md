# Run RuboCop and Fix Offenses

1. Check whether the project uses RuboCop (`Gemfile` has `rubocop`, `rubocop-rails`, `rubocop-rspec`, etc.; presence of `.rubocop.yml`).
2. Determine scope:
   - If the user specified files or directories, run RuboCop on that scope (e.g. `bundle exec rubocop app/models/user.rb`).
   - Otherwise run on the whole project (e.g. `bundle exec rubocop`).
3. Run RuboCop and note the offenses. Fix auto-correctable ones with `bundle exec rubocop -a` (or `-A`), or fix manually.
4. Re-run RuboCop on the same scope to confirm offenses are resolved.
5. If needed, run the test suite (`bundle exec rspec` or `bin/rails test`) to ensure changes did not break tests.

If the user said "this file only" or "specs only", run and fix within that scope.
