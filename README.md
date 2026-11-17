# nav_online_invoice

Ruby client for the Hungarian Tax Authority's (NAV) **Online Invoice API v3.0** (*Online Számla*).

> **Status: early development.** The next release provides `queryTaxpayer` (tax number lookup). Invoice queries
> and invoice submission follow later.

- **Plain Ruby, Rails optional.** Works in any Ruby process.
- **Per-client configuration.** One process can call NAV for several companies, each with its own technical user.
- **Few dependencies.** `Net::HTTP` and `openssl` from the standard library; the only runtime dependency is
  `nokogiri`, which ships precompiled for Linux, macOS and Windows.
- **Safe by default.** Every request gets a fresh request ID and signature (also on retry), outgoing XML is checked
  against NAV's official schemas, requests are rate limited, and credentials never appear in logs or `inspect`.
- **Typed errors.** Errors are mapped from NAV's `errorCode` and tell you whether trying again makes sense.

## Requirements

- Ruby 3.3 or newer (CRuby; tested on 3.3, 3.4 and 4.0, on Linux and Windows)
- A NAV Online Invoice technical user: login, password and signature key. Test and production users are separate;
  register a test user at <https://onlineszamla-test.nav.gov.hu>.

## Installation

```ruby
# Gemfile
gem "nav_online_invoice"
```

## Usage

```ruby
require "nav_online_invoice"

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
result.taxpayer.name                  # => "EXAMPLE KFT."
result.taxpayer.tax_number            # => "12345678-2-42"
result.taxpayer.incorporation         # => :organization, :self_employed or :taxable_person
result.taxpayer.headquarters.city     # addresses: :hq, :site or :branch
result.request_id                     # for your logs
```

An unknown tax number is not an error: `valid?` is `false` and `taxpayer` is `nil`.

The gem never reads environment variables or Rails credentials; pass the values in. Keep one `Client` per technical
user and reuse it; it is thread-safe.

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
| `logger` | `nil` | one line per request at `info`; request and response XML at `debug` |
| `request_id_generator` | `NavOnlineInvoice::RequestId` | any object with `call` |

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
- NAV allows **one request per second per IP address** on `queryTaxpayer` and some other operations, and delays
  the rest. The default throttle keeps one request per second within a process. If several processes share an
  IP address, pass a shared `throttle`: any object with `wait(operation_name)`, e.g. one using a database lock.

### Logging and personal data

At `info` level the gem logs one line per request: operation, request ID, attempt, HTTP status and duration. At
`debug` level it also logs the request XML, with the login, password hash and signature hidden, and NAV's answer.
The answer can contain personal data (the name and address of sole traders), so keep `debug` off in production.

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
3. Tag and push: `git tag v0.1.0 && git push origin v0.1.0`. GitHub Actions publishes the gem to RubyGems
   via trusted publishing.

## References

- NAV Online Invoice specification, schemas and samples: <https://github.com/nav-gov-hu/Online-Invoice>
- NAV common schema: <https://github.com/nav-gov-hu/Common>

## License

Released under the [MIT License](LICENSE.txt). The XML schemas in `schemas/` are © Nemzeti Adó- és Vámhivatal,
also under the MIT License.
