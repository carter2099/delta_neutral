# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.17] - 2026-06-17

### Changed
- Bumped brakeman, selenium-webdriver, hyperliquid, and tailwindcss-rails dependencies

### Security
- Bumped net-imap to 0.6.4.1 to address command injection via non-synchronizing literal ([CVE-2026-47240](https://nvd.nist.gov/vuln/detail/CVE-2026-47240), GHSA-8p34-64r3-mwg8), denial of service via incomplete validation ([CVE-2026-47241](https://nvd.nist.gov/vuln/detail/CVE-2026-47241), GHSA-c4fp-cxrr-mj66), and command injection via ID command argument ([CVE-2026-47242](https://nvd.nist.gov/vuln/detail/CVE-2026-47242), GHSA-46q3-7gv7-qmgg)

## [0.1.16] - 2026-06-10

### Changed
- Bumped sqlite3 dependency

## [0.1.15] - 2026-06-04

### Changed
- Bumped bootsnap and image_processing dependencies

### Security
- Bumped erb to 6.0.4 to address @_init deserialization guard bypass ([CVE-2026-41316](https://nvd.nist.gov/vuln/detail/CVE-2026-41316), GHSA-q339-8rmv-2mhv)

## [0.1.14] - 2026-05-27

### Changed
- Bumped image_processing to 2.0.1 (major version)

## [0.1.13] - 2026-05-27

### Changed
- Bumped yard dependency

## [0.1.12] - 2026-05-27

### Changed
- Bumped bootsnap, puma, hyperliquid, solid_cable, and jbuilder dependencies

### Security
- Bumped faraday to 2.14.2 to address incomplete fix for protocol-relative URI host scoping bypass ([CVE-2026-33637](https://nvd.nist.gov/vuln/detail/CVE-2026-33637), GHSA-5rv5-xj5j-3484)

## [0.1.11] - 2026-05-20

### Changed
- Bumped jbuilder and thruster dependencies

### Security
- Bumped net-imap to 0.6.4 to address DoS in SCRAM-* authentication ([GHSA-87pf-fpwv-p7m7](https://github.com/ruby/net-imap/security/advisories/GHSA-87pf-fpwv-p7m7)), command injection via raw arguments ([GHSA-hm49-wcqc-g2xg](https://github.com/ruby/net-imap/security/advisories/GHSA-hm49-wcqc-g2xg)), command injection via unvalidated Symbol inputs ([GHSA-75xq-5h9v-w6px](https://github.com/ruby/net-imap/security/advisories/GHSA-75xq-5h9v-w6px)), and related advisories ([GHSA-q2mw-fvj9-vvcw](https://github.com/ruby/net-imap/security/advisories/GHSA-q2mw-fvj9-vvcw), [GHSA-vcgp-9326-pqcp](https://github.com/ruby/net-imap/security/advisories/GHSA-vcgp-9326-pqcp))

## [0.1.10] - 2026-05-13

### Security
- Bumped addressable to 2.9.0 to address ReDoS in Addressable templates ([GHSA-h27x-rffw-24p4](https://github.com/sporkmonger/addressable/security/advisories/GHSA-h27x-rffw-24p4))
- Bumped rack-session to 2.1.2 to address session forgery via decrypt failure fallback ([GHSA-33qg-7wpp-89cq](https://github.com/rack/rack-session/security/advisories/GHSA-33qg-7wpp-89cq))

## [0.1.9] - 2026-05-13

### Changed
- Bumped hyperliquid, bootsnap, and selenium-webdriver dependencies

## [0.1.8] - 2026-05-06

### Changed
- Bumped hyperliquid, bootsnap, and sqlite3 dependencies

## [0.1.7] - 2026-04-29

### Changed
- Bumped puma, bootsnap, hyperliquid, and nokogiri dependencies

## [0.1.6] - 2026-04-23

### Changed
- Bumped rack, selenium-webdriver, puma (7→8), sqlite3, propshaft, and yard dependencies

### Security
- Updated action_text-trix to 2.1.18 to address XSS via JSON deserialization bypass in drag-and-drop ([GHSA-53p3-c7vp-4mcc](https://github.com/basecamp/trix/security/advisories/GHSA-53p3-c7vp-4mcc))

## [0.1.5] - 2026-03-25

### Changed
- Bumped thruster, solid_queue, nokogiri, rails, and bcrypt dependencies

## [0.1.4] - 2026-03-18

### Changed
- Bumped kamal, thruster, webmock, sqlite3, eth, brakeman, solid_queue, selenium-webdriver, web-console, trix, and actions/upload-artifact dependencies

## [0.1.3] - 2026-02-24

### Changed
- Pinned nokogiri >= 1.19.1 and rack >= 3.2.5 for security patches
- Updated actions/checkout from v5 to v6 in CI workflow

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
