---
name: clean-up
description: Swarm-review the Delta Neutral codebase for AI-generated slop and fix it. Launches 5 parallel agents across domain areas to find and remove dead code, unnecessary nil guards, unused API fields, and other violations of the AGENTS.md code quality rules.
---

# AI Slop Review — Delta Neutral

Perform a thorough review of the Delta Neutral codebase for AI-generated code quality issues ("slop"), then fix them.

## Step 1: Read the rules

Read `AGENTS.md` — the "Code Quality Guidelines" section is the authoritative ruleset. As of last review, the 13 rules are:

1. Only `includes()` what you access
2. Don't re-query loaded data
3. No unnecessary nil guards (`&.` when value is guaranteed, e.g. `Current.user` inside authenticated blocks)
4. No trivial helper wrappers
5. No phantom dependencies (gems not in Gemfile)
6. No dead code (unused methods, variables, scopes, unreachable branches)
7. No queries in views
8. `.size` over `.count` on loaded collections
9. Minimize API calls
10. Don't fetch unused fields from APIs (trim GraphQL queries)
11. Don't pass unused parameters
12. Don't hardcode single-user assumptions
13. No verbose/obvious comments — but **keep YARD docs and debug logging**, those are intentional

## Step 2: Launch 5 parallel review agents

Launch ALL agents in a single message using `Task` with `isolation: "worktree"` and `run_in_background: true`.

### Batch 1: Models & Database
**Files:** `app/models/**/*.rb`, `db/schema.rb`
**Focus:** Unnecessary nil guards, dead code, unused scopes, redundant validations/callbacks

### Batch 2: Controllers & Routes
**Files:** `app/controllers/**/*.rb`, `config/routes.rb`
**Focus:** Queries that should be in models/scopes, unnecessary nil guards inside authenticated blocks, dead actions, unused strong params, dead variable assignments

### Batch 3: Jobs & Services
**Files:** `app/jobs/**/*.rb`, `app/services/**/*.rb`
**Focus:** Phantom dependencies, unused parameters, over-fetching from APIs (GraphQL queries with unused fields, Hyperliquid response fields never read), dead methods confirmed by grep

### Batch 4: Views, Mailers & Frontend
**Files:** `app/views/**/*.erb`, `app/mailers/**/*.rb`, `app/javascript/**/*.js`, `app/helpers/**/*.rb`
**Focus:** Queries in views, dead helper methods, `.count` vs `.size` on preloaded collections

### Batch 5: Tests & Configuration
**Files:** `test/**/*.rb`, `config/**/*.rb`, `lib/**/*.rb`
**Focus:** Dead test helpers, unused fixtures/stubs, entirely commented-out initializer files, scaffold comments that ship with `rails new`

Each agent's prompt MUST include:
- The full 13-rule list from Step 1
- Its specific file patterns
- Instructions to read ALL files in scope, identify violations, and make fixes directly
- **DO NOT remove YARD documentation comments** (`@param`, `@return`, class-level docs, etc.)
- **DO NOT remove `Rails.logger.debug` calls** — structured debug logging is intentional
- Only remove methods/scopes with zero callers confirmed by grep
- Report a summary of every change with file paths and explanations

## Step 3: Collect results and apply changes

As agents complete, apply their changes to the working branch:
- Create patches from agent worktrees (`git diff HEAD > /tmp/batchN.patch`)
- Apply with `git apply`, using `--exclude` for conflicting files
- Resolve overlaps manually (common: two agents fixing the same view file)
- Clean up agent worktrees and branches after extracting patches

## Step 4: Verify

```bash
bin/rake  # Runs RuboCop + full test suite
```

Fix any failures. All tests and lint must pass before finishing.

## Step 5: Report

Summarize all changes grouped by category:
- **Dead code removed** — unused methods, variables, scopes, unreachable branches
- **Unused API data trimmed** — GraphQL fields, hash keys, response fields never read
- **Performance fixes** — `.count` to `.size`, N+1 queries
- **Dead configuration removed** — commented-out scaffold initializers
- **Other**

Include the final `git diff --stat`.
