# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-11-17

### Added

- `client.taxpayers.query`: tax number lookup (`queryTaxpayer`), returning the taxpayer's name, tax number,
  incorporation type and addresses.
- `NavOnlineInvoice::Configuration`: immutable, validated per-client settings; credentials hidden in `inspect`.
- `NavOnlineInvoice.configure` and `NavOnlineInvoice.client` for a single global configuration.
- Request signing (SHA-512 password hash, SHA3-512 request signature), checked against NAV's official examples.
- Validation of every request against NAV's XSD schemas, bundled in `schemas/`.
- Error classes mapped from NAV's error codes, with `retryable?`.
- Automatic retries of temporary failures, each with a new request ID and signature.
- A per-process throttle of one request per second, replaceable for multi-process setups.
- Logging with credentials hidden.

## [0.0.1] - 2026-11-17

### Added

- Project skeleton: gemspec, RSpec, RuboCop, GitHub Actions CI. No public API yet.

[Unreleased]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kilozdazolik/nav-online-invoice/releases/tag/v0.0.1
