# frozen_string_literal: true

module NavOnlineInvoice
  # Invoice queries. Use through {Client#invoices}.
  class Invoices
    # @api private
    def initialize(client)
      @client = client
    end

    # Asks whether an invoice number is valid at NAV, i.e. exists exactly once.
    #
    # @example
    #   client.invoices.check("INV-2026-0001", direction: :outbound) # => true
    # @param invoice_number [String]
    # @param direction [Symbol] +:outbound+ (issued by you) or +:inbound+ (received)
    # @param batch_index [Integer, nil] the invoice within a batch modification
    # @param supplier_tax_number [String, nil] only with +:inbound+
    # @return [Boolean]
    # @raise [ArgumentError] if a parameter is invalid
    def check(invoice_number, direction:, batch_index: nil, supplier_tax_number: nil)
      @client.execute(Operations::QueryInvoiceCheck.new(invoice_number, direction:, batch_index:,
                                                                        supplier_tax_number:))
    end

    # Fetches the full data of one invoice.
    #
    # @example
    #   result = client.invoices.data("INV-2026-0001", direction: :outbound)
    #   result&.document&.at_xpath("//data:invoiceNumber", "data" => "http://schemas.nav.gov.hu/OSA/3.0/data")
    # @param (see #check)
    # @return [InvoiceDataResult, nil] nil if NAV has no such invoice for you
    # @raise [ArgumentError] if a parameter is invalid
    # @raise [DecodeError] if the invoice data cannot be decoded
    def data(invoice_number, direction:, batch_index: nil, supplier_tax_number: nil)
      @client.execute(Operations::QueryInvoiceData.new(invoice_number, direction:, batch_index:,
                                                                       supplier_tax_number:))
    end
  end
end
