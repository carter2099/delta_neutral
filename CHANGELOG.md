# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.23] - 2026-08-19

### Changed
- Bumped brakeman from 8.0.5 to 8.0.6
- Bumped rack from 3.2.6 to 3.2.7
- Bumped selenium-webdriver from 4.46.0 to 4.47.0
- Bumped thruster from 0.1.23 to 0.1.25

### Security
- Bumped mail from 2.9.0 to 2.9.1 to address email address spoofing via malformed RFC 2047 encoded-words ([GHSA-mvxr-6m87-mv2q](https://github.com/mikel/mail/security/advisories/GHSA-mvxr-6m87-mv2q))

## [0.1.22] - 2026-08-14

### Changed
- Bumped bootsnap from 1.24.6 to 1.25.0
- Bumped image_processing from 2.0.2 to 2.0.3

### Security
- Bumped sqlite3 from 2.9.5 to 2.9.6 to address use-after-free in SQLite aggregate arguments in heap-allocated argument array ([GHSA-mwm8-39rw-8826](https://github.com/sparklemotion/sqlite3-ruby/security/advisories/GHSA-mwm8-39rw-8826))

## [0.1.21] - 2026-08-05

### Changed
- Bumped rails from 8.1.3 to 8.1.3.1
- Bumped solid_queue from 1.4.0 to 1.6.0

### Security
- Bumped json from 2.19.3 to 2.21.2 to address heap buffer overflow when streaming to an IO ([CVE-2026-54696](https://nvd.nist.gov/vuln/detail/CVE-2026-54696), [GHSA-x2f5-4prf-w687](https://github.com/ruby/json/security/advisories/GHSA-x2f5-4prf-w687))
- Bumped loofah from 2.25.1 to 2.25.2 to address javascript: URI bypass via numeric character references without semicolons ([GHSA-5qhf-9phg-95m2](https://github.com/flavorjones/loofah/security/advisories/GHSA-5qhf-9phg-95m2)), javascript: URI bypass via named whitespace character references ([GHSA-8whx-365g-h9vv](https://github.com/flavorjones/loofah/security/advisories/GHSA-8whx-365g-h9vv)), and SVG href attribute bypassing local-reference restriction ([GHSA-9wjq-cp2p-hrgf](https://github.com/flavorjones/loofah/security/advisories/GHSA-9wjq-cp2p-hrgf))
- Bumped rails-html-sanitizer from 1.7.0 to 1.7.1 to address possible XSS with certain configurations ([GHSA-cj75-f6xr-r4g7](https://github.com/rails/rails-html-sanitizer/security/advisories/GHSA-cj75-f6xr-r4g7))
- Bumped websocket-driver from 0.8.0 to 0.8.2 to address memory exhaustion via protocol length headers ([CVE-2026-54463](https://www.cve.org/CVERecord/SearchResults?query=CVE-2026-54463), [GHSA-ghhp-3qvg-889p](https://github.com/faye/websocket-driver-ruby/security/advisories/GHSA-ghhp-3qvg-889p)), resource limit bypass via message compression ([CVE-2026-54464](https://www.cve.org/CVERecord/SearchResults?query=CVE-2026-54464), [GHSA-33ph-fccm-39pj](https://github.com/faye/websocket-driver-ruby/security/advisories/GHSA-33ph-fccm-39pj)), memory exhaustion in HTTP header parser ([CVE-2026-54465](https://www.cve.org/CVERecord/SearchResults?query=CVE-2026-54465), [GHSA-8j3g-f24p-4mpw](https://github.com/faye/websocket-driver-ruby/security/advisories/GHSA-8j3g-f24p-4mpw)), and DoS via malformed Host header ([CVE-2026-61666](https://www.cve.org/CVERecord?id=CVE-2026-61666), [GHSA-2x63-gw47-w4mm](https://github.com/faye/websocket-driver-ruby/security/advisories/GHSA-2x63-gw47-w4mm))

## [0.1.20] - 2026-07-28

### Changed
- Bumped yard from 0.9.44 to 0.9.45
- Bumped selenium-webdriver from 4.45.0 to 4.46.0
- Bumped solid_cable from 4.0.0 to 4.0.2
- Bumped thruster from 0.1.22 to 0.1.23

## [0.1.19] - 2026-07-01

### Changed
- Bumped thruster from 0.1.21 to 0.1.22

### Security
- Bumped crass from 1.0.6 to 1.0.7 to address deeply nested CSS blocks and functions triggering SystemStackError or excessive memory usage ([GHSA-6jxj-px6v-747w](https://github.com/rgrove/crass/security/advisories/GHSA-6jxj-px6v-747w)), large numeric exponents causing CPU and memory denial of service ([GHSA-6wmf-3r64-vcwv](https://github.com/rgrove/crass/security/advisories/GHSA-6wmf-3r64-vcwv)), non-ASCII characters causing superlinear CPU consumption ([GHSA-8vfg-2r28-hvhj](https://github.com/rgrove/crass/security/advisories/GHSA-8vfg-2r28-hvhj)), and adjacent CSS comments triggering SystemStackError ([GHSA-wwpr-jff3-395c](https://github.com/rgrove/crass/security/advisories/GHSA-wwpr-jff3-395c))
- Bumped msgpack from 1.8.0 to 1.8.3 to address use-after-free in MessagePack::Buffer#clear enabling cross-buffer disclosure ([CVE-2026-54522](https://www.cve.org/CVERecord/SearchResults?query=CVE-2026-54522), [GHSA-4mrv-5p47-p938](https://github.com/msgpack/msgpack-ruby/security/advisories/GHSA-4mrv-5p47-p938))

## [0.1.18] - 2026-06-24

### Changed
- Bumped kamal from 2.11.0 to 2.12.0
- Bumped nokogiri from 1.19.3 to 1.19.4

### Security
- Bumped concurrent-ruby from 1.3.6 to 1.3.7 to address AtomicReference#update livelock with Float::NAN ([CVE-2026-54904](https://nvd.nist.gov/vuln/detail/CVE-2026-54904), GHSA-h8w8-99g7-qmvj), ReentrantReadWriteLock read-count overflow ([CVE-2026-54905](https://nvd.nist.gov/vuln/detail/CVE-2026-54905), GHSA-wv3x-4vxv-whpp), and ReadWriteLock wrong-thread write release ([CVE-2026-54906](https://nvd.nist.gov/vuln/detail/CVE-2026-54906), GHSA-6wx8-w4f5-wwcr)
- Bumped faraday from 2.14.2 to 2.14.3 to address uncontrolled recursion in NestedParamsEncoder allowing stack exhaustion DoS ([CVE-2026-54297](https://nvd.nist.gov/vuln/detail/CVE-2026-54297), GHSA-98m9-hrrm-r99r)

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
