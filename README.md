# nav_online_invoice

Ruby client for the Hungarian Tax Authority's (NAV) **Online Invoice API v3.0** (*Online Számla*).

> **Status: early development.** Version 0.0.1 is a project skeleton with no public API yet.
> The first usable release will provide `queryTaxpayer` (tax number lookup).

## Goals

- **Plain Ruby, Rails optional.** Works in any Ruby process; an optional Railtie wires up the Rails logger.
- **Per-client configuration.** One process can talk to NAV on behalf of several taxpayers, each with its
  own technical user. A global configuration is available as a convenience.
- **Few dependencies.** `Net::HTTP` and `openssl` from the standard library; the only runtime dependency is
  `nokogiri`, which ships precompiled for Linux, macOS and Windows.
- **Safe by default.** Every request gets a fresh request ID and signature (also on retry), outgoing XML is
  validated against NAV's official XSD schemas, requests are rate limited, and credentials never appear in
  logs or `inspect` output.
- **Typed errors.** Errors are mapped from NAV's `errorCode`, not the HTTP status, and tell you whether a
  retry makes sense.

## Planned API

```ruby
require "nav_online_invoice"

config = NavOnlineInvoice::Configuration.new(
  environment: :test,                 # :test or :production
  login: "...",
  password: "...",
  signature_key: "...",
  tax_number: "12345678",             # 8-digit tax number of the technical user's company
  software: {
    id: "HU12345678ABCDE-01",         # exactly 18 characters, [0-9A-Z-]
    name: "My invoicing app",
    operation: :local_software,       # or :online_service
    main_version: "1.0",
    dev_name: "...",
    dev_contact: "..."
  }
)

client = NavOnlineInvoice::Client.new(config)
result = client.taxpayers.query("12345678")

result.valid?        # => true if the tax number exists
result.taxpayer.name
```

The API above is a design target and may change before 0.1.0.

## Requirements

- Ruby 3.3 or newer (tested on 3.3, 3.4 and 4.0, on Linux and Windows)
- A NAV Online Invoice technical user. Test and production users are separate; register a test user at
  <https://onlineszamla-test.nav.gov.hu>.

## Installation

```ruby
# Gemfile
gem "nav_online_invoice"
```

## Development

The development environment runs in Docker; Ruby is not needed on the host.

```sh
bin/dev bundle install
bin/dev bundle exec rake            # specs + RuboCop
RUBY_VERSION=3.3 bin/dev bundle exec rspec
```

Never commit NAV credentials. Integration tests against the NAV test environment (planned) will read them
from a git-ignored `.env` file.

### Releasing

1. Update `VERSION` in `lib/nav_online_invoice/version.rb` and add a matching section to `CHANGELOG.md`.
2. Run `bin/dev bundle exec rake release:check`.
3. Tag and push: `git tag v0.1.0 && git push origin v0.1.0`. GitHub Actions publishes the gem to RubyGems
   via trusted publishing.

## References

- NAV Online Invoice specification, schemas and samples: <https://github.com/nav-gov-hu/Online-Invoice>
- NAV common schema (`Common-1.0.RC3` tag): <https://github.com/nav-gov-hu/Common>

## License

Released under the [MIT License](LICENSE.txt). NAV's XML schemas, once bundled, are © Nemzeti Adó- és
Vámhivatal, also under the MIT License.
