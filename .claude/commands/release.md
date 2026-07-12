---
description: Commit a manual version bump in version.rb, tag it, and publish the gem to RubyGems
---

The user has manually edited `lib/rails_authentication/version.rb` to bump `RailsAuthentication::VERSION`. Your job is to ship that version.

Steps:

1. Read `lib/rails_authentication/version.rb` and extract the new version string (call it `VERSION`).
2. Run `git status` and `git diff lib/rails_authentication/version.rb`. Confirm the only relevant uncommitted change is the version bump (there may also be unrelated staged/unstaged work — do not touch that). If `version.rb` is unchanged from what's already committed/tagged, stop and tell the user there's nothing new to release.
3. Check that tag `vVERSION` doesn't already exist (`git tag -l "vVERSION"`). If it does, stop and report the conflict.
4. Run `bundle exec rake spec` (generator specs) as a safety check before publishing. If it fails, stop and report the failure — do not proceed to commit/tag/publish.
5. Stage and commit just `lib/rails_authentication/version.rb` with message `Bump version to VERSION`.
6. Show the user a summary (new version, commit, tag name `vVERSION`, that this will push to `origin` and publish to RubyGems) and confirm before proceeding — this step is not reversible.
7. Once confirmed, run `bundle exec rake release`. This is bundler's standard release task: it builds the gem, creates git tag `vVERSION`, pushes the commit and tag to `origin`, and pushes the built gem to RubyGems.
8. Report the result: the tag pushed and the RubyGems push output (or the failure, if `gem push` rejected it — e.g. missing credentials in `~/.gem/credentials`, or the version already taken).

Do not skip the confirmation in step 6 — publishing to RubyGems cannot be undone (versions can only be yanked, not overwritten), and pushing tags/commits to `origin` is visible to anyone watching the repo.
