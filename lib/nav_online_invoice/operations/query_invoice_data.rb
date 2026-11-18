# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Fetches the full data of one invoice.
    class QueryInvoiceData < Base
      include InvoiceNumberQuery

      def name = "queryInvoiceData"

      # @return [InvoiceDataResult, nil] nil if NAV has no such invoice for you
      # @raise [DecodeError] if the invoice data cannot be decoded
      def parse(document, request_id:, raw_xml:)
        result = document.root.at_xpath("api:invoiceDataResult", NAMESPACES)
        return unless result

        compressed = boolean(result, "api:compressedContentIndicator")
        hash = result.at_xpath("api:electronicInvoiceHash", NAMESPACES)
        InvoiceDataResult.new(
          request_id: request_id,
          invoice_xml: Payload.decode(text(result, "api:invoiceData"), compressed: compressed),
          compressed: compressed,
          audit_data: audit_data(result.at_xpath("api:auditData", NAMESPACES)),
          electronic_invoice_hash: hash && ElectronicInvoiceHash.new(value: hash.text, crypto_type: hash["cryptoType"]),
          raw_xml: raw_xml
        )
      end

      private

      def audit_data(node)
        AuditData.new(
          # The schema spells it insdate, unlike insDate everywhere else.
          ins_date: time(node, "api:insdate"),
          ins_cus_user: text(node, "api:insCusUser"),
          source: symbol(node, "api:source"),
          transaction_id: text(node, "api:transactionId"),
          index: integer(node, "api:index"),
          batch_index: integer(node, "api:batchIndex"),
          original_request_version: text(node, "api:originalRequestVersion")
        )
      end
    end
  end
end
