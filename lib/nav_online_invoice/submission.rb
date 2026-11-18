# frozen_string_literal: true

module NavOnlineInvoice
  # A submission NAV has received. It is not yet accepted: follow it with {Transactions#wait} or
  # {Transactions#status}.
  #
  # @!attribute transaction_id
  #   @return [String]
  # @!attribute item_count
  #   @return [Integer] the invoices or annulments sent; their index is their position in the request, from 1
  # @!attribute compressed
  #   @return [Boolean] whether the invoices were sent gzipped
  # @!attribute electronic_invoice_hashes
  #   @return [Array<String, nil>] the electronicInvoiceHash sent for each item, in index order
  Submission = Data.define(:transaction_id, :request_id, :item_count, :compressed, :electronic_invoice_hashes)
end
