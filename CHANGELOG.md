# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.2] - 2026-02-24

### Added
- Production Docker Compose setup (`docker-compose.prod.yml`)
- Auto-trigger `HedgeSyncJob` on hedge creation for immediate sync

### Fixed
- Nil price crash on position show page during first-time setup (before prices sync)
- Asset precompilation with `SECRET_KEY_BASE_DUMMY` bypassing env var validation
- Recurring job schedule not loading in development environment

### Changed
- Dockerfile now includes `libsecp256k1-dev` and related build dependencies
- Enabled `assume_ssl` in production for SSL-terminating reverse proxy

## [0.1.1] - 2026-02-22

### Added
- Development job logs now broadcast to stdout via foreman

### Fixed
- Consistent dollar formatting with correct negative sign placement

### Changed
- Job queue (failed/pending/in_progress) now sorts most-recent-first

## [0.1.0] - 2026-02-21

### Added
- Fee tracking for hedge positions
- Hyperliquid subaccount architecture for same-asset short isolation
- Positions detail UI improvements
- Hedge UI improvements

### Fixed
- Pool PnL tracking
- Foreman env configuration
- Linting errors

### Changed
- CI improvements
- Hedge sync and rebalance improvements
- Removed inline sync-now from rebalance prompt

## [0.0.1] - 2026-02-21

- Initial release
