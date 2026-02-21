# AGENTS.md — Delta Neutral Architecture Guide

## Overview

Delta Neutral is a single-user, self-hosted auto hedge rebalancer. It monitors Uniswap V3 concentrated liquidity positions and rebalances Hyperliquid short hedges based on configurable target/tolerance percentages.

## Tech Stack

- **Framework:** Rails 8.1.1
- **Database:** SQLite (via Solid Queue, Solid Cache, Solid Cable)
- **Background Jobs:** Solid Queue with recurring schedule
- **Frontend:** Hotwire (Turbo + Stimulus), Tailwind CSS v4
- **Asset Pipeline:** Propshaft + ImportMap
- **Version:** Defined in `config/version.rb` as `DeltaNeutral::VERSION`, displayed in the navbar

## Architecture

### Domain Models

```
User
├── Wallet (address, network)
│   └── Position (asset pair, amounts, prices, external_id)
│       ├── Hedge (target%, tolerance%, active, asset0_hl_account, asset1_hl_account)
│       │   └── ShortRebalance (old/new short size, realized PnL, status, message)
│       └── PnlSnapshot (captured amounts, prices, hedge PnL, collected/uncollected fees)
├── Network (lookup: ethereum, arbitrum, base, optimism, polygon)
└── Dex (lookup: uniswap, hyperliquid)
```

### Service Layer

- **UniswapService** — GraphQL queries to The Graph's decentralized subgraph for Uniswap V3 position data, token prices (via derivedETH * ethPriceUSD), pool state, and collected fee data per position
- **HyperliquidService** — Wrapper around the `hyperliquid` gem SDK for opening/closing shorts, fetching positions, PnL data, and managing subaccounts for per-hedge isolation
- **EthereumService** — JSON-RPC client (via `eth` gem) for on-chain reads; fetches uncollected LP fees by static-calling `NonfungiblePositionManager.collect()` with MAX_UINT128 amounts

### Background Jobs (Solid Queue)

| Job | Schedule | Purpose |
|-----|----------|---------|
| WalletSyncJob | Every 1 min | Discover/deactivate Uniswap positions per wallet |
| PositionSyncJob | Every 1 min | Update prices, fetch collected + uncollected LP fees, create PnL snapshots |
| HedgeSyncJob | Every 5 min | Check tolerances, rebalance shorts, send email notifications |

### Key Business Logic

The `Hedge#needs_rebalance?` method determines when to rebalance:
```ruby
def needs_rebalance?(pool_amount, current_short)
  target_short = pool_amount * target
  (target_short - current_short).abs > (target_short * tolerance)
end
```

**Per-asset independence:** The two assets in a position are managed independently. When a pool asset drops to zero (position fully out of range on that side), its target short is also zero, so `needs_rebalance?` triggers on the existing open short, closes it, records a `ShortRebalance` with `new_short_size: 0`, and sends the owner a `rebalance_notification`. The hedge stays active so the sibling asset's short continues to be managed. If the asset re-enters range, the next sync detects `current_short: 0` vs `target_short > 0` and reopens the short automatically.

**Failed rebalance tracking:** Every rebalance attempt is recorded as a `ShortRebalance` with `status: "success"` or `status: "failed"`. Failed records include a `message` with the attempted order size and error details (e.g., Hyperliquid's $10 minimum order rejection). The UI shows failed rebalances with a clickable red badge that expands to reveal the error message.

**Consecutive failure circuit breaker:** If the last 3 rebalances for a given hedge+asset (within 24 hours) all failed, `HedgeSyncJob` skips further attempts for that asset. This prevents polluting the rebalance history with repeated identical failures (e.g., an order that's permanently below the $10 minimum). The circuit breaker resets naturally when a rebalance succeeds, when failures age past 24 hours, or when the user adjusts hedge settings.

**Hyperliquid subaccount isolation:** When two hedges share the same HL asset (e.g., two ETH/USDC pools), their shorts would collide on the same account. Each hedge stores per-asset account assignments in `asset0_hl_account` and `asset1_hl_account` (`nil` = main account). The allocation algorithm:

1. If the main account is free for this asset (no other active hedge uses it), use main (leave column `nil`)
2. If main is taken, find the first existing subaccount not in use for this asset
3. If no subaccount is available, create a new one (Hyperliquid max: 10 subaccounts)

USDC transfers: Before opening a short on a subaccount, `HedgeSyncJob` calculates the required margin (`target_short × mark_price / leverage × 1.2` buffer), checks the subaccount balance, and transfers only the difference from main. When closing to zero on a subaccount, all USDC is withdrawn back to main and the account column is cleared. The same cleanup happens when a hedge is destroyed via `HedgesController#destroy`.

### Controllers

All controllers require authentication (via Rails 8 generated `Authentication` concern):
- **DashboardController** — Summary stats, positions overview, recent rebalances
- **WalletsController** — CRUD + sync_now
- **PositionsController** — Index/show + sync_now (with PnL/rebalance history)
- **HedgesController** — Full CRUD + sync_now
- **Mission Control Jobs** — Solid Queue dashboard mounted at `/jobs` (via `mission_control-jobs` gem, inherits app auth via `base_controller_class`)

### Email

- **HedgeRebalanceMailer** — `rebalance_notification` sent to `position.user.email_address` on every rebalance. When `new_short_size` is zero the pool asset hit zero (position out of range); no replacement short is opened but the hedge stays active for re-entry.

## Environment Variables

**Setup:** Copy `.env.example` to `.env` and fill in the values. The `.env` file is gitignored.

**How env vars are loaded:**
- `dotenv-rails` (in the `:development, :test` Gemfile group) auto-loads `.env` via its Railtie during Rails boot
- `bin/jobs` explicitly loads dotenv before Rails boot (`require "dotenv/load"`) to ensure Solid Queue worker processes always have access to `.env` vars, regardless of process forking behavior
- `config/initializers/app_config.rb` validates that all required vars are present at boot time (in all environments except test) and raises immediately with a helpful error if any are missing

**Required variables** (validated at boot in development and production):
- `HYPERLIQUID_PRIVATE_KEY`, `HYPERLIQUID_WALLET_ADDRESS`
- `UNISWAP_SUBGRAPH_URL`, `THEGRAPH_API_KEY`
- `ETHEREUM_RPC_URL`, `ARBITRUM_RPC_URL`, `BASE_RPC_URL` (per-network Alchemy/Infura JSON-RPC endpoints for on-chain fee reads)

**If you add a new required env var:**
1. Add it to `.env.example` with a blank or example value
2. Add it to the `required_vars` list in `config/initializers/app_config.rb`
3. Add it to the `env.secret` or `env.clear` section in `config/deploy.yml` for production

## Development

```bash
bin/dev          # Start web server + Solid Queue + Tailwind watcher
bin/rake         # Run lint (RuboCop) + tests (default Rake task)
bin/rails db:seed # Seed lookup tables + dev admin user (admin@example.com / password123)
```

## Testing

Tests use WebMock for HTTP stubbing and simple mock objects for SDK interactions. Service stubs are in `test/support/service_stubs.rb`.

## Verification Checklist

**Before finishing any task that touches code, always run:**

```bash
bin/rake          # Runs RuboCop lint AND full test suite (the default Rake task)
```

Both linting and tests must pass with zero offenses/failures. Do not consider a task complete until `bin/rake` exits cleanly.

## Versioning

The app version lives in `config/version.rb` as `DeltaNeutral::VERSION`. This is the single source of truth — it's loaded via `config/application.rb` and displayed in the navbar layout. To cut a release:

1. Update the version in `config/version.rb`
2. Add a new section to `CHANGELOG.md` under the new version heading (e.g., `## [0.0.2] - 2026-03-01`)
3. Commit, tag (`git tag v0.0.2`), and push with `--tags`
4. The `release.yml` workflow automatically creates a GitHub Release using the CHANGELOG entry

## File Organization

```
app/
├── controllers/    # Dashboard, Wallets, Positions, Hedges + auth
├── jobs/           # WalletSync, PositionSync, HedgeSync
├── mailers/        # HedgeRebalanceMailer
├── models/         # User, Wallet, Position, Hedge, PnlSnapshot, ShortRebalance, Network, Dex
├── services/       # UniswapService, HyperliquidService, EthereumService
└── views/          # Tailwind dark-themed UI
```

## Debugging

- **Check logs, but verify they're recent.** `log/development.log` contains job output, service errors, and stack traces. All processes (web, jobs, css) write to the same log, so entries can interleave. Always check timestamps to ensure you're reading logs from the current session, not stale entries from a previous run. Grep for the job or service name (e.g., `HedgeSyncJob`, `HyperliquidService`) to trace execution flow.
- **Query the database.** Use `bin/rails runner` to inspect model state directly (e.g., `ShortRebalance.order(created_at: :desc).limit(5)`, `Hedge.active`, `Position.find(1)`). This is often faster and more reliable than parsing logs.

## Code Quality Guidelines

These rules prevent common AI-generated code issues. Follow them strictly.

- **Only `includes()` what you access.** Only eager-load associations actually used by the consumer (view, job, or downstream code). Don't speculatively include associations "just in case."
- **Don't re-query loaded data.** If data is already eager-loaded or fetched in a prior query, filter it in Ruby instead of issuing a new database query.
- **No unnecessary nil guards.** Don't use `&.` or bare `rescue` when the value is guaranteed by control flow (e.g., `Current.user` inside an `authenticated?` block).
- **No trivial helper wrappers.** Don't wrap framework-provided methods (like `authenticated?`) in aliases (like `user_signed_in?`). Use the original directly.
- **No phantom dependencies.** Never reference gems or classes not in the Gemfile. A `retry_on SomeGem::Error` for an uninstalled gem is a latent `NameError`.
- **No dead code.** Remove unused methods, always-zero variables, and unreachable branches. If a method is never called, delete it.
- **No queries in views.** Database queries belong in controllers or jobs. Views receive data via instance variables set by the controller.
- **`.size` over `.count` on loaded collections.** Use `.size` on relations that will be (or already are) loaded — it uses the in-memory collection. `.count` always fires a `SELECT COUNT(*)` query.
- **Minimize API calls.** When an external API returns a superset of the data you need, call it once and filter locally. Don't make N calls when 1 suffices.
- **Don't fetch unused fields from APIs.** Trim GraphQL queries and return hashes to only include fields the consumer actually reads.
- **Don't pass unused parameters.** Every parameter a method declares must be used by that method. If a parameter is only used to extract sub-values before the call, extract them at the call site and pass the values directly.
- **Don't hardcode single-user assumptions.** This app targets single-user self-hosting, but don't force it. Use model relationships (e.g., `position.user.email_address`) instead of global config (e.g., `ENV["NOTIFICATION_EMAIL"]`). Data that belongs to a user should be derived from the user record, not from environment variables or constants.
