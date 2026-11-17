# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "openssl"
require "securerandom"
require "uri"

require_relative "nav_online_invoice/version"
require_relative "nav_online_invoice/errors"
require_relative "nav_online_invoice/schema_validator"
require_relative "nav_online_invoice/crypto"
require_relative "nav_online_invoice/request_id"
require_relative "nav_online_invoice/tax_number"
require_relative "nav_online_invoice/throttle"
require_relative "nav_online_invoice/redactor"
require_relative "nav_online_invoice/configuration"
require_relative "nav_online_invoice/request_builder"
require_relative "nav_online_invoice/transport"

# Each client gets its own configuration, so one application can call the
# Online Invoice API for several companies.
#
# @see https://github.com/nav-gov-hu/Online-Invoice NAV API documentation
module NavOnlineInvoice
end
