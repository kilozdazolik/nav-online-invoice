# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Invoice queries: `client.invoices.digest` and `each_digest` (queryInvoiceDigest, with every NAV filter),
  `check` (queryInvoiceCheck), `data` (queryInvoiceData, with the invoice decoded) and `chain_digest` and
  `each_chain_element` (queryInvoiceChainDigest).
- Transaction queries: `client.transactions.list` and `each_transaction` (queryTransactionList) and `status`
  (queryTransactionStatus, with validation messages and the original request decoded).
- `NavOnlineInvoice::Page` for paged results; lazy paging with an optional `max_pages`.
- Parameters are checked before sending (date ranges, open relational ranges, enums, amounts).
- `log_payloads` setting; `DecodeError`; `SchemaValidator` can check invoices against the data schema.
- `script/windows_smoke.rb` to check an installation on a machine without a compiler.
- Invoice submission: `client.invoices.submit` (tokenExchange and manageInvoice, up to 100 invoices, gzip when
  needed, `electronicInvoiceHash` for electronic invoices) and technical annulment: `client.invoices.annul`
  (manageAnnulment). Submissions are sent once and never retried.
- `client.transactions.wait` follows a submission until NAV has processed it; `client.transactions.reconcile`
  finds out whether a submission without an answer arrived (spec 1.9.2).
- `UnknownOutcomeError`, `ExchangeTokenError`, `SubmissionTooLargeError` and `TransportError#request_sent?`.
- `ProcessingResult#final?` and `#pending?`; `TransactionStatus#finished?`, `#annulment_pending?` and `#annulled?`.
- The `exchange_key` setting is checked (16 characters).

### Changed

- Request and response XML is no longer logged at `debug` level unless `log_payloads: true` is set, and invoice
  data is hidden even then.
- `ApiError::TechnicalValidationMessage#result_code` is a Symbol (`:error`, `:critical`) instead of a String.
- New runtime dependency: `bigdecimal` (any version shipped with Ruby 3.3 or later).
- `INVALID_EXCHANGE_TOKEN` raises `ExchangeTokenError` (a `RequestError`).

## [0.1.0] - 2026-11-17

### Added

- `client.taxpayers.query`: tax number lookup (`queryTaxpayer`), returning the taxpayer's name, tax number,
  incorporation type and addresses. `TaxpayerResult#matches?` checks a full 11-digit tax number.
- `NavOnlineInvoice::Configuration`: immutable, validated per-client settings; credentials hidden in `inspect`,
  `pp` and `to_h`.
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
