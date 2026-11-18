# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Submits up to 100 technical annulments with one exchange token (spec 1.8.1).
    class ManageAnnulment < Manage
      def name = "manageAnnulment"

      def build_body(xml)
        xml.exchangeToken @token.value
        xml.annulmentOperations do
          @items.each.with_index(1) do |item, index|
            xml.annulmentOperation do
              xml.index index
              xml.annulmentOperation item.operation
              xml.invoiceAnnulment item.data
            end
          end
        end
      end
    end
  end
end
