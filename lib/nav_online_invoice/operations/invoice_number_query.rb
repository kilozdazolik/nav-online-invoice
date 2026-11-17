# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # The invoiceNumberQuery shared by queryInvoiceData and queryInvoiceCheck.
    module InvoiceNumberQuery
      # @param invoice_number [String]
      # @param direction [Symbol] +:outbound+ (issued by you) or +:inbound+ (received)
      # @param batch_index [Integer, nil] the invoice within a batch modification
      # @param supplier_tax_number [String, nil] for inbound invoices, when several suppliers used the number
      # @raise [ArgumentError]
      def initialize(invoice_number, direction:, batch_index: nil, supplier_tax_number: nil)
        super()
        @invoice_number = Params.text(:invoice_number, invoice_number, max: 50)
        @direction = Params.direction(direction)
        @batch_index = batch_index && Params.positive_integer(:batch_index, batch_index)
        @supplier_tax_number = supplier_tax_number && Params.tax_number(:supplier_tax_number, supplier_tax_number)
        return unless @supplier_tax_number && @direction == "OUTBOUND"

        raise ArgumentError, "supplier_tax_number is only allowed with direction: :inbound"
      end

      def auto_retry? = true

      def build_body(xml)
        xml.invoiceNumberQuery do
          xml.invoiceNumber @invoice_number
          xml.invoiceDirection @direction
          xml.batchIndex @batch_index if @batch_index
          xml.supplierTaxNumber @supplier_tax_number if @supplier_tax_number
        end
      end
    end
  end
end
