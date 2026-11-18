# frozen_string_literal: true

module NavOnlineInvoice
  Submission = Data.define(:transaction_id, :request_id, :item_count, :compressed, :electronic_invoice_hashes)

  # A submission NAV has received. It is not yet accepted: follow it with {Transactions#wait} or
  # {Transactions#status}.
  #
  # @!attribute transaction_id
  #   @return [String]
  # @!attribute request_id
  #   @return [String] the ID of the manageInvoice or manageAnnulment request, for your logs
  # @!attribute item_count
  #   @return [Integer] the invoices or annulments sent; their index is their position in the request, from 1
  # @!attribute compressed
  #   @return [Boolean] whether the invoices were sent gzipped
  # @!attribute electronic_invoice_hashes
  #   @return [Array<ElectronicInvoiceHash, nil>] the electronicInvoiceHash sent for each item, in index order
  class Submission
    # Whether the invoices were sent gzipped.
    def compressed? = compressed == true
  end
end
