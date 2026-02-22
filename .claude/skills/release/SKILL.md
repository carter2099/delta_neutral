---
name: release
description: Cut a new release. Takes a version number as argument (e.g., /release 0.2.0). Updates version file and changelog, pauses for user to review, then pushes with tags after the user commits.
---

# Release — Delta Neutral

Cut a new release for the given version number (passed as the argument, e.g. `0.2.0`).

## Step 1: Read AGENTS.md

Read `AGENTS.md` for the latest versioning and release instructions.

## Step 2: Update version file

Update `config/version.rb` to the new version number.

## Step 3: Generate changelog entry

1. Identify the previous version's git tag (e.g. `v0.1.1`).
2. Run `git log <previous-tag>..HEAD --oneline` and `git diff <previous-tag>..HEAD` to review all changes since the last release.
3. Draft a changelog entry under `## [<version>] - <today's date>` using Keep a Changelog format (Added/Fixed/Changed sections as appropriate).
4. Write the entry into `CHANGELOG.md` above the previous version's heading.

## Step 4: Pause for user review

**STOP and ask the user to review the changelog and version changes.** Tell them:
- Review `CHANGELOG.md` and `config/version.rb`
- Make any edits they want
- Commit when ready (e.g. `git add -A && git commit -m "version to <version>"`)
- Tell you when the commit is done

**Do NOT proceed until the user confirms their commit is done.**

## Step 5: Tag and push

Once the user confirms:

1. Run `git tag v<version>`
2. Run `git push && git push --tags`
3. Confirm the tag is pushed and the release workflow will pick it up.
