# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and the project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `InvoiceDataResult#invoice` and `#invoices` read the invoice of `invoices.data` into an `Invoice` record: supplier,
  customer and fiscal representative with tax numbers, addresses and bank account numbers; the invoice details such
  as currency, exchange rate, payment method and deadline; the reference of a modification; and the totals by VAT
  rate. A missing gross total is added up from the invoice's own amounts. Lines are not included.
- `Invoice#to_h` and the other new records return nested hashes, ready to be written as JSON.
- `UnsupportedInvoiceVersionError`, a `DecodeError`, for invoices sent in the 1.x or 2.0 formats.
- `Address#additional_address_detail` and `Address#simple?`, for NAV's simple address form; `type`, `street_name`
  and `public_place_category` are now optional.
- `TaxNumber.format`.

### Fixed

- Amounts written as `+5`, `.5` or `5.`, all valid `xs:decimal` forms, are read instead of becoming `nil`.

## [0.3.0] - 2026-11-18

### Fixed

- `transactions.reconcile` searches by NAV's clock: `UnknownOutcomeError#sent_at` is NAV's time of sending, worked
  out from the exchange token, and the window runs from five minutes before to ten minutes after it (spec 1.9.2).
  A wrong local clock or a long throttle wait could hide the transaction and lead to a duplicate submission.
- `reconcile` no longer counts an annulment, or a submission NAV aborted, as an arrived invoice; it refuses to run
  on a `with_predecessor` client, whose list shows the predecessor's submissions.
- An invoice with `completenessIndicator` written as `1` gets its `electronicInvoiceHash`.
- A submission answered with a 4xx that is not a NAV answer raises the `TransportError` (rejected) instead of
  `UnknownOutcomeError`.
- `TransactionStatus#accepted?` is false while there are no results.
- `transactions.each_transaction` checks its parameters before the first request.
- `NOT_ALLOWED_EXCEPTION` raises `RequestError`, not `PermissionError`.
- The generated Rails initializer leaves the gem unconfigured instead of stopping the boot when the credentials
  have no `nav` entry.

### Changed

- **Breaking:** `ExchangeTokenError` inherits from `ApiError`, not `RequestError`, since submitting again is safe.
- **Breaking:** electronic invoice hashes are `NavOnlineInvoice::ElectronicInvoiceHash` values in
  `Submission#electronic_invoice_hashes` and `InvoiceDataResult#electronic_invoice_hash`;
  `InvoiceDataResult#electronic_invoice_hash_type` is gone. `submit` takes a Hash or an `ElectronicInvoiceHash`.
- **Breaking:** `reconcile` returns `{ invoice_number => [transaction_id, ...] }` and takes `annulment: true` for
  annulments.
- `TechnicalValidationMessage` is a top-level class; `ApiError::TechnicalValidationMessage` still refers to it.
- `Submission#compressed?`, `Transaction#technical_annulment?` and `InvoiceDigest#complete?`.
- Queries retry a bare 503 from a network device; NAV's own `MAINTENANCE_MODE` is still not retried.
- `nokogiri` 1.19.5 or later.

### Security

- Schema validation messages leave the rejected values out (`SchemaValidationError#message`); the full messages
  stay in `#errors`. `ArgumentError` messages no longer quote free text or tax numbers.
- `Taxpayer` and `Address` leave the name and the address out of `inspect`; `pp` of every result and of every
  operation shows the same redacted text; `to_h` of the exchange token and of a submitted item hides their data.
- The Railtie hides the login, the password and the keys in `config.nav_online_invoice` once applied.
- Unpacking gzip data stops at 20 MB; requests go only over https with a verified certificate and TLS 1.2 or later;
  the log redactor also covers CDATA, comments and prefixes with dots or hyphens.

## [0.2.0] - 2026-11-18

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
- `client.with_predecessor` sends `predecessorTaxNumber`, to query and annul the data of a predecessor company.
- `NavOnlineInvoice::Metrics` and `client.metrics` read NAV's service metrics (queryServiceMetrics).
- Rails integration: a Railtie that uses `Rails.logger` by default and turns `config.nav_online_invoice` into the
  global configuration, and `rails generate nav_online_invoice:install`.
- `NavOnlineInvoice.default_logger` for configurations that set no logger.
- `Client#predecessor_tax_number`, `UnknownOutcomeError#reconcile_window`, `Crypto.index_hash`,
  `Crypto.electronic_invoice_hash` and `Crypto.decrypt_token`; the log line has a `bytes=` field.

### Changed

- Request and response XML is no longer logged at `debug` level unless `log_payloads: true` is set, and invoice
  data is hidden even then.
- `ApiError::TechnicalValidationMessage#result_code` is a Symbol (`:error`, `:critical`) instead of a String.
- New runtime dependency: `bigdecimal` (any version shipped with Ruby 3.3 or later).
- `INVALID_EXCHANGE_TOKEN` raises `ExchangeTokenError` (a `RequestError`).

### Security

- 0.1.0 logged NAV's answers at `debug` level without hiding anything; 0.2.0 logs no XML unless `log_payloads` is
  set, and hides credentials and invoice data even then.

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

[Unreleased]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/kilozdazolik/nav-online-invoice/compare/v0.0.1...v0.1.0
[0.0.1]: https://github.com/kilozdazolik/nav-online-invoice/releases/tag/v0.0.1
