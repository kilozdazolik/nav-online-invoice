# frozen_string_literal: true

module NavOnlineInvoice
  # XML namespaces of the NAV API.
  #
  # @api private
  NAMESPACES = {
    "api" => "http://schemas.nav.gov.hu/OSA/3.0/api",
    "common" => "http://schemas.nav.gov.hu/NTCA/1.0/common",
    "base" => "http://schemas.nav.gov.hu/OSA/3.0/base",
    "data" => "http://schemas.nav.gov.hu/OSA/3.0/data",
    "annul" => "http://schemas.nav.gov.hu/OSA/3.0/annul",
    "metrics" => "http://schemas.nav.gov.hu/OSA/3.0/metrics"
  }.freeze
end
