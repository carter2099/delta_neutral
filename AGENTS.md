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
│       ├── Hedge (target%, tolerance%, active)
│       │   └── ShortRebalance (old/new short size, realized PnL)
│       └── PnlSnapshot (captured amounts, prices, hedge PnL)
├── Network (lookup: ethereum, arbitrum, base, optimism, polygon)
└── Dex (lookup: uniswap, hyperliquid)
```

### Service Layer

- **UniswapService** — GraphQL queries to The Graph's decentralized subgraph for Uniswap V3 position data, token prices (via derivedETH * ethPriceUSD), and pool state
- **HyperliquidService** — Wrapper around the `hyperliquid` gem SDK for opening/closing shorts, fetching positions, and PnL data

### Background Jobs (Solid Queue)

| Job | Schedule | Purpose |
|-----|----------|---------|
| WalletSyncJob | Every 1 min | Discover/deactivate Uniswap positions per wallet |
| PositionSyncJob | Every 1 min | Update prices, create PnL snapshots |
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

### Controllers

All controllers require authentication (via Rails 8 generated `Authentication` concern):
- **DashboardController** — Summary stats, positions overview, recent rebalances
- **WalletsController** — CRUD + sync_now
- **PositionsController** — Index/show + sync_now (with PnL/rebalance history)
- **HedgesController** — Full CRUD + sync_now

### Email

- **HedgeRebalanceMailer** — `rebalance_notification` sent to `position.user.email_address` on every rebalance. When `new_short_size` is zero the pool asset hit zero (position out of range); no replacement short is opened but the hedge stays active for re-entry.

## Environment Variables

See `.env.example` for the full list. Required in production:
- `HYPERLIQUID_PRIVATE_KEY`, `HYPERLIQUID_WALLET_ADDRESS`
- `UNISWAP_SUBGRAPH_URL`, `THEGRAPH_API_KEY`

## Development

```bash
bin/dev          # Start web server + Solid Queue + Tailwind watcher
bin/rails test   # Run all tests
bin/rails db:seed # Seed lookup tables + dev admin user (admin@example.com / password123)
```

## Testing

Tests use WebMock for HTTP stubbing and simple mock objects for SDK interactions. Service stubs are in `test/support/service_stubs.rb`.

## Versioning

The app version lives in `config/version.rb` as `DeltaNeutral::VERSION`. This is the single source of truth — it's loaded via `config/application.rb` and displayed in the navbar layout. When bumping the version, update that constant and tag the release (`git tag v0.0.2`).

## File Organization

```
app/
├── controllers/    # Dashboard, Wallets, Positions, Hedges + auth
├── jobs/           # WalletSync, PositionSync, HedgeSync
├── mailers/        # HedgeRebalanceMailer
├── models/         # User, Wallet, Position, Hedge, PnlSnapshot, ShortRebalance, Network, Dex
├── services/       # UniswapService, HyperliquidService
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
