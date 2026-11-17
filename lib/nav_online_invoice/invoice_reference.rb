# frozen_string_literal: true

module NavOnlineInvoice
  # What a modification or storno invoice refers to.
  #
  # @!attribute original_invoice_number
  #   @return [String] the invoice being modified
  # @!attribute modify_without_master
  #   @return [Boolean] whether the original invoice was never reported to NAV
  # @!attribute modification_timestamp
  #   @return [Time, nil] set by invoices in the 1.x formats
  # @!attribute modification_index
  #   @return [Integer, nil] set by invoices in the 2.0 format and later
  InvoiceReference = Data.define(:original_invoice_number, :modify_without_master, :modification_timestamp,
                                 :modification_index)
end
