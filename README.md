# nav_online_invoice

[![Gem Version](https://badge.fury.io/rb/nav_online_invoice.svg)](https://rubygems.org/gems/nav_online_invoice)
[![CI](https://github.com/kilozdazolik/nav-online-invoice/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/kilozdazolik/nav-online-invoice/actions/workflows/ci.yml)

Ruby client for the Hungarian Tax Authority's (NAV) **Online Invoice API v3.0** (*Online Számla*).

> **Status:** tax number lookups, invoice queries and transaction queries are supported. Invoice submission follows
> in a later version. The API may change before 1.0.

- **Plain Ruby, Rails optional.** Works in any Ruby process.
- **Per-client configuration.** One process can call NAV for several companies, each with its own technical user.
- **Few dependencies.** `Net::HTTP` and `openssl` from the standard library; runtime dependencies are `nokogiri`,
  which ships precompiled for Linux, macOS and Windows, and `bigdecimal`, which comes with Ruby.
- **Safe by default.** Every request gets a fresh request ID and signature (also on retry), outgoing XML is checked
  against NAV's official schemas, requests are rate limited, and credentials are hidden in logs, `inspect`, `pp`
  and `to_h`.
- **Typed errors.** Errors are mapped from NAV's `errorCode` and tell you whether trying again makes sense.

## Requirements

- Ruby 3.3 or newer (CRuby; tested on 3.3, 3.4 and 4.0, on Linux and Windows)
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
result.taxpayer.headquarters.city     # addresses: :hq, :site or :branch
result.request_id                     # for your logs
```

An unknown tax number is not an error: `valid?` is `false` and `taxpayer` is `nil`. NAV checks only the first 8
digits, so `valid?` is also true for `12345678-9-99`; use `matches?` to check a full tax number.

The gem never reads environment variables or Rails credentials; pass the values in. Keep one `Client` per technical
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
`max_pages` or narrow the filters.

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

### Types

Dates are `Date`, timestamps `Time` in UTC, amounts `BigDecimal`, NAV's codes lowercase symbols (`:outbound`,
`:storno`, `:done`). Paged queries return a `NavOnlineInvoice::Page` with `items`, `current_page` and
`total_pages`. `inspect` and `pp` of the results leave out names, addresses, amounts and invoice contents.

### Global configuration

For an application with a single technical user:

```ruby
# config/initializers/nav_online_invoice.rb
NavOnlineInvoice.configure do |config|
  config.environment = Rails.env.production? ? :production : :test
  config.login = Rails.application.credentials.dig(:nav, :login)
  config.password = Rails.application.credentials.dig(:nav, :password)
  config.signature_key = Rails.application.credentials.dig(:nav, :signature_key)
  config.tax_number = Rails.application.credentials.dig(:nav, :tax_number)
  config.software = { id: "...", name: "...", operation: :online_service, main_version: "1.0",
                      dev_name: "...", dev_contact: "..." }
  config.logger = Rails.logger
end

NavOnlineInvoice.client.taxpayers.query("12345678")
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
| `logger` | `nil` | one line per request at `info`, without any content |
| `log_payloads` | `false` | also log the XML at `debug`; never in production, see below |
| `request_id_generator` | `NavOnlineInvoice::RequestId` | any object with `call` |
| `exchange_key` | `nil` | only needed to submit invoices (not supported yet) |
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
| `TransportError` | timeout, connection error, or a response that is not XML | if `retryable?` |
| `AuthenticationError` | `INVALID_SECURITY_USER`, `INVALID_REQUEST_SIGNATURE`, ... | no |
| `PermissionError` | `FORBIDDEN`: the technical user lacks the permission | no |
| `CustomerError` | `NOT_REGISTERED_CUSTOMER`, `INVALID_CUSTOMER`, `INVALID_USER_RELATION`, ... | no |
| `RequestError` | `INVALID_REQUEST`, `INVALID_TIMESTAMP`, `BAD_QUERY_PARAM_*`, ... | no |
| `MaintenanceError` | NAV is under maintenance | no (`retryable?` is true: try again later) |
| `TemporaryError` | `OPERATION_FAILED`, `REQUEST_ID_NOT_UNIQUE` | yes |
| `DecodeError` | NAV sent invoice data that is not valid base64, gzip or UTF-8 | no |

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
- Only temporary failures are retried. In the worst case one call takes about `(max_retries + 1) × read_timeout`.
- NAV allows **one request per second per IP address** on `queryTaxpayer`, `queryInvoiceData` and
  `queryTransactionStatus` (and on invoice submission), and delays the rest. The default throttle keeps one such
  request per second within a process; the other queries are not throttled. If several processes share an
  IP address, pass a shared `throttle`: any object with `wait(operation_name)`, e.g. one using a database lock.

### Logging and personal data

The gem logs one line per request at `info` level: operation, request ID, attempt, HTTP status, duration and size.
It never logs request or response XML, unless you set `log_payloads: true`; then both go to `debug`, with the
login, password hash, signature and the base64 invoice data hidden.

**Do not set `log_payloads` in production.** Even with invoice data hidden, the XML contains names, addresses, tax
numbers and amounts of your partners, and for sole traders that is personal data. Use it against NAV's test
environment only.

### Windows

The gem needs no compiler: `nokogiri` ships precompiled, and `bigdecimal` comes with Ruby. Keep your lock file on
the `bigdecimal` version your Ruby ships with (`gem list bigdecimal`), because there is no precompiled Windows build
of newer versions. To check an installation on a machine without a compiler, run
[script/windows_smoke.rb](script/windows_smoke.rb) after `gem install --local nav_online_invoice-X.Y.Z.gem`.

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

NAV's XML schemas are copied into `schemas/`; see [schemas/README.md](schemas/README.md) for their source and how
to update them.

### Releasing

1. Update `VERSION` in `lib/nav_online_invoice/version.rb` and add a matching section to `CHANGELOG.md`.
2. Run `bin/dev bundle exec rake release:check`.
3. Commit (`Release 0.1.0`), push and wait for CI.
4. Tag and push: `git tag -a v0.1.0 -m "Version 0.1.0" && git push origin v0.1.0`. GitHub Actions publishes the
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
