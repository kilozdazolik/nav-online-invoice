# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Submits up to 100 invoices with one exchange token (spec 1.8.2).
    class ManageInvoice < Manage
      # @param token [ExchangeToken]
      # @param items [Array<Manage::Item>] in index order
      # @param compressed [Boolean] whether the data of every item is gzipped
      def initialize(token:, items:, compressed:)
        super(token:, items:)
        @compressed = compressed
      end

      def name = "manageInvoice"

      def build_body(xml)
        xml.exchangeToken @token.value
        xml.invoiceOperations do
          xml.compressedContent @compressed
          @items.each.with_index(1) { |item, index| build_item(xml, item, index) }
        end
      end

      private

      def compressed? = @compressed

      def build_item(xml, item, index)
        xml.invoiceOperation do
          xml.index index
          xml.invoiceOperation item.operation
          xml.invoiceData item.data
          if (hash = item.electronic_invoice_hash)
            xml.electronicInvoiceHash(hash[:value], "cryptoType" => hash[:crypto_type])
          end
        end
      end
    end
  end
end
