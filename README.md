# Delta Neutral

A Rails dashboard for monitoring Uniswap V3 concentrated liquidity positions and rebalancing Hyperliquid short positions to maintain delta hedging.

## Requirements

- Ruby 3.4.3
- Rails 8.1.2
- SQLite3

## Setup

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:create db:migrate

# Create initial user
bin/rails db:seed
# Or create manually:
# bin/rails console
# User.create!(email_address: "you@example.com", password: "your_password")

# Copy environment file and configure
cp .env.example .env
# Edit .env with your GRAPH_API_KEY

# Configure Hyperliquid credentials (for live trading)
bin/rails credentials:edit
# Add:
# hyperliquid:
#   private_key: "your_private_key"
#   wallet_address: "0x..."

# Start the server
bin/dev
```

## Features

- **Position Tracking**: Monitor Uniswap V3 positions on Ethereum and Arbitrum
- **Hedge Management**: Configure hedge ratios and token mappings
- **Auto-Rebalancing**: Automatic rebalancing when drift exceeds threshold
- **Paper Trading**: Test strategies without executing real trades
- **Email Notifications**: Alerts for rebalancing events
- **Dark Theme UI**: Clean, minimal interface

## Testing

```bash
bin/rails test                    # Run all tests
bin/rails test test/services/     # Run service tests
bin/rails test test/models/       # Run model tests
```

## Architecture

### Services
- `app/services/uniswap/` - Liquidity math and tick calculations
- `app/services/subgraph/` - GraphQL client for The Graph
- `app/services/hyperliquid/` - Hyperliquid SDK wrapper
- `app/services/hedging/` - Hedge calculation and safety validators

### Background Jobs
- `PositionPollingSchedulerJob` - Triggers sync for all positions (every 30s)
- `PositionSyncJob` - Fetches position data from subgraph
- `HedgeAnalysisJob` - Analyzes drift and triggers rebalancing
- `RebalanceExecutionJob` - Executes rebalance orders

## Safety Features

- **Paper Trading Mode**: Simulate orders without execution
- **Testnet Mode**: Use Hyperliquid testnet
- **Circuit Breaker**: Halts trading after consecutive failures
- **Safety Validator**: Trade size limits and drift validation
