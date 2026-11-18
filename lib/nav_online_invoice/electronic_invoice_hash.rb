# frozen_string_literal: true

module NavOnlineInvoice
  # The hash of an electronic invoice, as NAV stores it next to the invoice data.
  #
  # @!attribute value
  #   @return [String] uppercase hex
  # @!attribute crypto_type
  #   @return [String] "SHA3-512" or "SHA-256"
  ElectronicInvoiceHash = Data.define(:value, :crypto_type)
end
