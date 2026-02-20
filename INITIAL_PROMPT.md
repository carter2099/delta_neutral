DeltaNeutral

Rough outline/architecture

Purpose:
- Auto hedge rebalancer. Uses ruby hyperliquid sdk: https://github.com/carter2099/hyperliquid and uniswap subgraph to interact with uniswap v3 CLPs and hyperliquid shorts.
- CLPs are entered by the user via uniswap, hedges are created and rebalanced via this application
- This application is to be a single user self hosted rails application that monitors and rebalances the hedges based on a target hedge % and % tolerance to keep the hedges balanced within
    - i.e.: for an ETH/BTC pool with 50% targets, ETH and BTC shorts are opened at 50% of the pool amounts. For 10% tolerance, starting at 1 ETH pool amount, init 0.5 ETH, if abs((poolAmount * 0.5) - 0.5) > 0.05, the app closes the short, records pnl, and opens a new short at 50% of the new pool amt of ETH
- Email notifications on hedge rebalance
- PnL tracking for at-a-glance monitoring of hedged CLP positions

Technical Architecture:
- Domains
    - User: first name, last name, email
    - Wallet: user id, network id, address
    - Position: asset0, asset1, asset0 amount, asset1 amount, asset0 price usd, asset1 price usd, dex id, user id
    - Hedge: position id (unique), target, tolerance
    - PnlSnapshot: position id, datetime, asset0, asset1, hedgeunrealized, hedgerealized
    - ShortRebalance: hedge id, timestamp, asset, realizedpnl
    - Lookup tables:
        - Network (eth, arb, base, etc)
        - Dex (hyperliquid, uniswap)
- ActiveJob
    - WalletSyncJob (1m): detect new positions for wallets
    - PositionSyncJob (1m): sync positions: update position data, create pnl snapshot
    - HedgeSyncJob (5m): detect if hedge outside of tolerance range and if so, close shorts, create shortrebalance (one to two records depending both shorts need it), record pnl snapshot, queue email update
- Service layer
    - Hyperliquid service: wrapper for ruby hyperliquid sdk
    - UniSwap service: contains subgraph interface
- Controller layer
    - Wallet syncnow (queue wallet sync run immediately)
    - Position show/detail, syncnow (queue position sync run immediately)
    - Hedge crud, syncnow (queue hedge sync run immediately)
- Configuration (env)
    - hl wallet private key
    - smpt configuration

