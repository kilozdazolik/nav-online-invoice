# nav_online_invoice

[![Gem Version](https://badge.fury.io/rb/nav_online_invoice.svg)](https://rubygems.org/gems/nav_online_invoice)
[![CI](https://github.com/kilozdazolik/nav-online-invoice/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kilozdazolik/nav-online-invoice/actions/workflows/ci.yml)

Ruby client for the Hungarian Tax Authority's (NAV) **Online Invoice API v3.0** (*Online Számla*).

> **Status:** the whole API is supported: tax number lookups, invoice and transaction queries, invoice submission,
> technical annulment, predecessor companies and the service metrics. The API may change before 1.0.

- **Plain Ruby, Rails optional.** Works in any Ruby process.
- **Per-client configuration.** One process can call NAV for several companies, each with its own technical user.
- **Few dependencies.** `Net::HTTP` and `openssl` from the standard library; runtime dependencies are `nokogiri`,
  which ships precompiled for Linux, macOS and Windows, and `bigdecimal`, which comes with Ruby.
- **Safe by default.** Every request gets a fresh request ID and signature (also on retry), outgoing XML is checked
  against NAV's official schemas, requests are rate limited, and credentials are hidden in logs, `inspect`, `pp`
  and `to_h`.
- **Submissions are sent once.** Invoices are never resent automatically; when no answer arrives, a dedicated error
  says so and `reconcile` finds out whether they arrived.
- **Typed errors.** Errors are mapped from NAV's `errorCode` and tell you whether trying again makes sense.

## Requirements

- Ruby 3.3 or newer (CRuby; tested on 3.3, 3.4 and 4.0 on Linux, and on 4.0 on Windows)
- A NAV Online Invoice technical user: login, password and signature key. Test and production users are separate;
  register a test user at <https://onlineszamla-test.nav.gov.hu>.

## Installation

```sh
bundle add nav_online_invoice
```

Or without Bundler:

```sh
gem install nav_online_invoice
```

## Usage

```ruby
require "nav_online_invoice"
require "logger" # only for the logger below; on Ruby 4.0 add the logger gem to your Gemfile

config = NavOnlineInvoice::Configuration.new(
  environment: :test,                 # :test or :production
  login: "...",
  password: "...",                    # or password_hash: "..." (SHA-512, hex)
  signature_key: "...",
  exchange_key: "...",                # only needed to submit invoices
  tax_number: "12345678",             # the technical user's company; 8 or 11 digits
  software: {
    id: "HU12345678ABCDE-01",         # exactly 18 characters of 0-9, A-Z and -
    name: "My invoicing app",
    operation: :local_software,       # or :online_service
    main_version: "1.0",
    dev_name: "Example Ltd.",
    dev_contact: "dev@example.com",   # must be a working e-mail address
    dev_country_code: "HU",           # optional
    dev_tax_number: "12345678-2-42"   # optional
  },
  logger: Logger.new($stdout)         # optional
)

client = NavOnlineInvoice::Client.new(config)
result = client.taxpayers.query("12345678-2-42")

result.valid?                         # => true if the tax number exists
result.matches?("12345678-2-42")      # => true if the VAT and county codes match too
result.taxpayer.name                  # => "EXAMPLE KFT."
result.taxpayer.tax_number            # => "12345678-2-42"
result.taxpayer.incorporation         # => :organization, :self_employed or :taxable_person
result.taxpayer.headquarters&.city    # addresses: :hq, :site or :branch
result.request_id                     # for your logs
```

An unknown tax number is not an error: `valid?` is `false` and `taxpayer` is `nil`. NAV checks only the first 8
digits, so `valid?` is also true for `12345678-9-99`; use `matches?` to check a full tax number.

The gem itself never reads environment variables or Rails credentials; pass the values in. Keep one `Client` per technical
user and reuse it; it is thread-safe.

### Querying invoices

```ruby
november = Date.new(2026, 11, 1)..Date.new(2026, 11, 30)

page = client.invoices.digest(direction: :outbound, issue_date: november)  # up to 100 per page
page.each { |invoice| puts "#{invoice.invoice_number} #{invoice.customer_name} #{invoice.net_amount_huf}" }
page.total_pages

# All pages, fetched only as far as you read them:
client.invoices.each_digest(direction: :inbound, issue_date: november, max_pages: 20) do |invoice|
  # ...
end

client.invoices.check("INV-2026-0001", direction: :outbound)   # => true if valid at NAV
result = client.invoices.data("INV-2026-0001", direction: :outbound)
result.invoice_xml                                              # the invoice in NAV's InvoiceData format
result.document                                                 # the same, parsed with Nokogiri
client.invoices.chain_digest("INV-2026-0001", direction: :outbound) # the invoice and its modifications
```

`digest` needs exactly one of `issue_date` (at most 35 days), `ins_date` (when NAV received it, at most 840
hours) and `original_invoice_number`. Further filters: `tax_number`, `group_member_tax_number`, `name` (the other
party), `category`, `payment_method`, `appearance`, `source`, `currency`, `transaction_id`, `index`, `operation`,
and `delivery_date`, `payment_date`, `net_amount`, `net_amount_huf`, `vat_amount`, `vat_amount_huf`, which take a
single value or a range with both ends (`10_000..500_000`); NAV accepts no open ranges.

Parameters are checked before sending; a bad one raises `ArgumentError`. `data` returns `nil` when NAV has no such
invoice for you. A long `each_digest` can walk many pages, and NAV's data can change while it does: set
`max_pages` or narrow the filters. Every paged query has an `each_` method named after its items: `digest` and
`each_digest`, `chain_digest` and `each_chain_element`, `transactions.list` and `each_transaction`.

### Transactions

```ruby
page = client.transactions.list(ins_date: (Time.now - 86_400)..Time.now) # submissions of the last day
status = client.transactions.status(page.items.first.transaction_id)
status.accepted?                                                       # all invoices done, without errors
status.results.each do |result|
  puts "#{result.index} #{result.status}"
  result.business_validation_messages.each { |m| puts "  #{m.result_code} #{m.error_code} #{m.message}" }
end
```

### Submitting invoices

The gem does not build invoices: pass the finished
[InvoiceData 3.0](https://github.com/nav-gov-hu/Online-Invoice/tree/master/src/schemas/nav/gov/hu/OSA) XML your
invoicing software produced. The gem checks it against NAV's schema, encodes and signs it, requests a single-use
exchange token, and sends up to 100 invoices in one request.

```ruby
submission = client.invoices.submit([
  { operation: :create, xml: invoice_xml },
  { operation: :storno, xml: storno_xml }
])
submission.transaction_id                     # NAV received the request; processing is asynchronous

status = client.transactions.wait(submission.transaction_id, timeout: 120)
status.finished?                              # NAV finished with every invoice
status.accepted?                              # ... and all of them are DONE without errors
status.results.reject { |r| r.done? && !r.errors? }.map(&:index) # positions (from 1) to fix and submit again
```

- **Sent once, never retried.** A NAV error answer (`ApiError`), or a 4xx without one, means nothing was stored, so
  the invoices can be sent again. `UnknownOutcomeError` means the request was sent but no answer arrived: the
  invoices may be at NAV. Do not resend them blindly; after five minutes, ask NAV:

  ```ruby
  rescue NavOnlineInvoice::UnknownOutcomeError => e
    # five minutes later, e.g. from a background job:
    found = client.transactions.reconcile(sent_at: e.sent_at, invoice_numbers: numbers)
    # => { "INV-2026-0001" => ["4Q8O2ZCTX1J8WGZ2"] }; submit the rest again
  ```

  `e.sent_at` is NAV's time of sending, worked out from the exchange token, so a wrong local clock does not hide the
  transaction. Aborted submissions do not count as arrived; for annulments pass `annulment: true`.

- **Partial failures.** Each invoice is processed on its own. Submit only the aborted ones again, in a new call.
- **Size.** NAV accepts at most 10 MB per request and 15 MB per invoice. With `compress: :auto` (the default) the
  invoices are gzipped only when the request would be too large; `compress: true` or `false` decides yourself.
- **Electronic invoices.** When the XML itself is the electronic invoice (`completenessIndicator` true), the gem
  computes its `electronicInvoiceHash`. Otherwise pass the hash of your own electronic invoice file:
  `electronic_invoice_hash: { value: "...", crypto_type: "SHA-256" }` (or `"SHA3-512"`). The submission returns the
  hashes it sent as `NavOnlineInvoice::ElectronicInvoiceHash` values.
- `wait` returns the last status at the timeout instead of raising; store it and ask again later with `status`.

### Technical annulment

```ruby
annulment = client.invoices.annul([
  { reference: "INV-2026-0001", code: :erratic_data, reason: "Sent with a wrong customer" }
])
status = client.transactions.wait(annulment.transaction_id)
status.annulment_pending?                     # waits for approval on NAV's web interface
status.annulled?                              # approved: the invoice number can be submitted again
```

`code` is one of `:erratic_data`, `:erratic_invoice_number`, `:erratic_invoice_issue_date` and
`:erratic_electronic_hash_value`. An annulment takes effect only after a user approves it on NAV's web interface.

### Predecessor companies

After a merger or split, the successor can work with the data of its predecessor:

```ruby
predecessor = client.with_predecessor("11111111-2-41")  # a new client; `client` is unchanged
predecessor.invoices.digest(direction: :outbound, issue_date: from..to)
predecessor.transactions.status(transaction_id)
predecessor.invoices.annul([{ reference: "OLD-0001", code: :erratic_data, reason: "Wrong customer" }])
```

Its queries search the predecessor's invoices and submissions, and `annul` annuls the predecessor's invoices. Tax
number lookups and submissions are not affected; an invoice submitted on behalf of a predecessor says so in its own
data. NAV limits what a successor sees: after a split only the data up to the date of the split, without
`return_original_request` (so `reconcile` does not work), and after leaving a VAT group no transaction queries.

### Service metrics

NAV publishes the average response time of each operation and the average invoice processing time of the last
hour, refreshed every minute. No credentials are needed:

```ruby
metrics = NavOnlineInvoice::Metrics.new(environment: :production)    # or client.metrics
metrics.get("responseTimeAverageMsManageInvoice")&.values&.last&.value # => 135.47 (ms, BigDecimal)
metrics.all.metrics.map(&:name)                                        # every metric with its values
metrics.definitions                                                    # names and descriptions only
```

`get` returns `nil` for an unknown name. NAV keeps the metrics in memory only, so they can be empty after a restart.

### Types

Dates are `Date`, timestamps `Time` in UTC, amounts `BigDecimal`, NAV's codes lowercase symbols (`:outbound`,
`:storno`, `:done`). Paged queries return a `NavOnlineInvoice::Page` with `items`, `current_page` and
`total_pages` (and `last_page?`). `inspect` and `pp` of the results leave out names, addresses, amounts and invoice
contents.

### Global configuration

For an application with a single technical user:

```ruby
NavOnlineInvoice.configure do |config|
  config.environment = :production
  config.login = "..."
  # ... the same settings as Configuration.new
end

NavOnlineInvoice.client.taxpayers.query("12345678")
```

`NavOnlineInvoice.default_logger = logger` sets the logger of every configuration that sets none; `logger: nil`
still turns logging off.

### Rails

The gem loads a Railtie when Rails is present. It reads no credentials or environment variables; the application
passes the values in.

```sh
bin/rails generate nav_online_invoice:install   # creates config/initializers/nav_online_invoice.rb
```

The generated initializer reads the technical user from the credentials (`bin/rails credentials:edit`, under
`nav:`) and calls `NavOnlineInvoice.configure`. Instead of an initializer, the settings can also go into the
application's configuration:

```ruby
# config/application.rb or config/environments/production.rb
config.nav_online_invoice.environment = :production
config.nav_online_invoice.login = Rails.application.credentials.dig(:nav, :login)
# ... any setting of Configuration.new
```

- `Rails.logger` is the default logger, unless a configuration sets its own.
- An unknown or invalid setting stops the application at boot with a `ConfigurationError`.
- The gem logs none of its settings. Rails' default `filter_parameters` (`:passw`, `:_key`, `:token`, `:secret`)
  cover the password and the keys if your own code passes them as request parameters; the login is not secret.
- For several companies, skip the global configuration and keep one `Client` per company.

The gem ships no background jobs; follow submissions from your own:

```ruby
class NavSubmissionJob < ApplicationJob
  def perform(transaction_id)
    status = NavOnlineInvoice.client.transactions.wait(transaction_id, timeout: 60)
    return retry_job(wait: 1.minute) unless status&.finished?

    # store status.accepted? and status.results
  end
end
```

### Options

| Option | Default | |
|---|---|---|
| `open_timeout` | `5` | seconds to connect |
| `read_timeout` | `60` | seconds to wait for an answer; NAV's own limit is 60 s |
| `write_timeout` | `60` | seconds to send |
| `max_retries` | `2` | retries of temporary failures (3 attempts in total) |
| `retry_base_delay` | `1.0` | seconds before the first retry; doubles on each retry |
| `throttle` | shared `Throttle` | at most one request per second per process; `nil` turns it off |
| `validate_requests` | `true` | check each request against NAV's schema before sending |
| `logger` | `NavOnlineInvoice.default_logger` (`Rails.logger` under Rails) | one line per request at `info`, without any content; `nil` for none |
| `log_payloads` | `false` | also log the XML at `debug`; never in production, see below |
| `request_id_generator` | `NavOnlineInvoice::RequestId` | any object with `call` |
| `exchange_key` | `nil` | 16 characters; only needed to submit invoices and annulments |
| `clock` | `Time.method(:now)` | any object with `call` returning a `Time`; for tests |

For an interactive lookup, e.g. on a form, use a shorter `read_timeout` and fewer retries:
`config.with(read_timeout: 10, max_retries: 0)`.

## Errors

All errors inherit from `NavOnlineInvoice::Error`. `error.retryable?` tells whether sending the request again later
can succeed.

| Error | When | Retried by the gem |
|---|---|---|
| `ConfigurationError` | a setting is missing or malformed | no |
| `SchemaValidationError` | the request does not match NAV's schema; it was not sent | no |
| `TransportError` | timeout, connection error, or a response that is not XML; `request_sent?` is false if the connection failed | if `retryable?`, except submissions |
| `UnknownOutcomeError` | a submission was sent but got no answer; see `reconcile` | no |
| `SubmissionTooLargeError` | a submission is over NAV's size limits; it was not sent | no |
| `AuthenticationError` | `INVALID_SECURITY_USER`, `INVALID_REQUEST_SIGNATURE`, ... | no |
| `PermissionError` | `FORBIDDEN`: the technical user lacks the permission | no |
| `CustomerError` | `NOT_REGISTERED_CUSTOMER`, `INVALID_CUSTOMER`, `INVALID_USER_RELATION`, ... | no |
| `RequestError` | `INVALID_REQUEST`, `INVALID_TIMESTAMP`, `BAD_QUERY_PARAM_*`, ... | no |
| `ExchangeTokenError` | `INVALID_EXCHANGE_TOKEN`: wrong exchange key, or the token expired; nothing was stored | no (`retryable?` is true) |
| `MaintenanceError` | NAV is under maintenance, or a network device answered 503 | only a query's bare 503 (`retryable?` is true: try again later) |
| `TemporaryError` | `OPERATION_FAILED`, `REQUEST_ID_NOT_UNIQUE` | yes, except submissions |
| `DecodeError` | NAV sent invoice data that is not valid base64, gzip or UTF-8, or a token the exchange key does not decrypt | no |

Invalid parameters raise Ruby's `ArgumentError` before anything is sent.

Every `ApiError` (the parent of the NAV error classes) has `code`, `nav_message`, `request_id`, `http_status` and
`technical_validation_messages`. An error code the gem does not know is raised as a plain `ApiError`.

```ruby
begin
  client.taxpayers.query(tax_number)
rescue NavOnlineInvoice::PermissionError => e
  # ask the primary user to grant the permission in NAV's user management
rescue NavOnlineInvoice::Error => e
  retry_later if e.retryable?
end
```

### Retries and rate limiting

- Each attempt gets a **new request ID, timestamp and signature**. NAV rejects a reused request ID, including the
  ID of a request it refused with `FORBIDDEN` or `INVALID_REQUEST_SIGNATURE`.
- Only temporary failures of queries and token requests are retried. Submissions (`submit`, `annul`) are never
  retried. In the worst case one call takes about `(max_retries + 1) × read_timeout`.
- NAV allows **one request per second per IP address** on `queryTaxpayer`, `queryInvoiceData`,
  `queryTransactionStatus`, `tokenExchange`, `manageInvoice` and `manageAnnulment`, and delays the rest. The default
  throttle keeps one such request per second within a process; the other queries are not throttled. If several processes share an
  IP address, pass a shared `throttle`: any object with `wait(operation_name)`, e.g. one using a database lock.

### Logging and personal data

The gem logs one line per request at `info` level: operation, request ID, attempt, HTTP status, duration and size.
It never logs request or response XML, unless you set `log_payloads: true`; then both go to `debug`, with the
login, password hash, signature, exchange tokens and the base64 invoice and annulment data hidden.

**Do not set `log_payloads` in production.** Even with invoice data hidden, the XML contains names, addresses, tax
numbers and amounts of your partners, and for sole traders that is personal data. Use it against NAV's test
environment only.

### Windows

The gem needs no compiler: `nokogiri` ships precompiled, and `bigdecimal` comes with Ruby. Keep your lock file on
the `bigdecimal` version your Ruby ships with (`gem list bigdecimal`), because there is no precompiled Windows build
of newer versions. To check an installation on a machine without a compiler, run
[script/windows_smoke.rb](https://github.com/kilozdazolik/nav-online-invoice/blob/main/script/windows_smoke.rb) after `gem install --local nav_online_invoice-X.Y.Z.gem`.

## Development

The development environment runs in Docker; Ruby is not needed on the host.

```sh
bin/dev bundle install
bin/dev bundle exec rake                 # specs + RuboCop
RUBY_VERSION=3.3 bin/dev bundle exec rspec
```

In VS Code, **Dev Containers: Reopen in Container** opens the project in a Ruby 4.0 container with
[Ruby LSP](https://shopify.github.io/ruby-lsp/) (documentation on hover, go to definition, RuboCop).

To call NAV for real, copy `.env.example` to `.env`, fill it in (never commit it), and run:

```sh
bin/dev sh -c 'NAV_INTEGRATION=1 bundle exec rspec spec/integration'
```

The service metrics spec needs no `.env`. The submission spec sends an invented invoice, so it runs only against NAV's test environment and only with
`NAV_ALLOW_SUBMISSION=1` and `NAV_EXCHANGE_KEY` set.

NAV's XML schemas are copied into `schemas/`; see [schemas/README.md](schemas/README.md) for their source and how
to update them.

### Releasing

1. Update `VERSION` in `lib/nav_online_invoice/version.rb` and add a matching section to `CHANGELOG.md`.
2. Run `bin/dev bundle exec rake release:check`.
3. Commit (`Release X.Y.Z`), push and wait for CI.
4. Tag and push: `git tag -a vX.Y.Z -m "Version X.Y.Z" && git push origin vX.Y.Z`. GitHub Actions publishes the
   gem to RubyGems via trusted publishing and creates the GitHub release from the CHANGELOG section.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Contributing

Bug reports and pull requests are welcome on GitHub at <https://github.com/kilozdazolik/nav-online-invoice>.
Please never include real NAV credentials or taxpayer data in issues, fixtures or logs.

## References

- NAV Online Invoice specification, schemas and samples: <https://github.com/nav-gov-hu/Online-Invoice>
- NAV common schema: <https://github.com/nav-gov-hu/Common>

## License

Released under the [MIT License](LICENSE.txt). The XML schemas in `schemas/` are © Nemzeti Adó- és Vámhivatal,
also under the MIT License.
