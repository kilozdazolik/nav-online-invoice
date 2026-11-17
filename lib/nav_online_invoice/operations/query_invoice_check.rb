# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Asks whether an invoice number is valid at NAV.
    class QueryInvoiceCheck < Base
      include InvoiceNumberQuery

      def name = "queryInvoiceCheck"
      def rate_limited? = false

      # @return [Boolean]
      def parse(document, **) # rubocop:disable Naming/PredicateMethod -- the operation contract names it parse
        boolean(document.root, "api:invoiceCheckResult") == true
      end
    end
  end
end
