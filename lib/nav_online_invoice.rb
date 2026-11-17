# frozen_string_literal: true

require_relative "nav_online_invoice/version"

# Each client gets its own configuration, so one application can call the
# Online Invoice API for several companies.
#
# @see https://github.com/nav-gov-hu/Online-Invoice NAV API documentation
module NavOnlineInvoice
  # Base class for all errors raised by this gem.
  #
  # Rescue this to handle any NAV-related failure in one place.
  #
  # @example
  #   begin
  #     client.taxpayers.query("12345678")
  #   rescue NavOnlineInvoice::Error => e
  #     logger.error(e.message)
  #   end
  class Error < StandardError; end
end
