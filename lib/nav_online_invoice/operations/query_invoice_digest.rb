# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Lists invoices matching search conditions, one page at a time.
    class QueryInvoiceDigest < Base
      DIGEST_FIELDS = {
        invoice_number: [:text, "invoiceNumber"], batch_index: [:integer, "batchIndex"],
        operation: [:symbol, "invoiceOperation"], category: [:symbol, "invoiceCategory"],
        issue_date: [:date, "invoiceIssueDate"], supplier_tax_number: [:text, "supplierTaxNumber"],
        supplier_group_member_tax_number: [:text, "supplierGroupMemberTaxNumber"],
        supplier_name: [:text, "supplierName"], customer_tax_number: [:text, "customerTaxNumber"],
        customer_group_member_tax_number: [:text, "customerGroupMemberTaxNumber"],
        customer_name: [:text, "customerName"], payment_method: [:symbol, "paymentMethod"],
        payment_date: [:date, "paymentDate"], appearance: [:symbol, "invoiceAppearance"],
        source: [:symbol, "source"], delivery_date: [:date, "invoiceDeliveryDate"], currency: [:text, "currency"],
        net_amount: [:decimal, "invoiceNetAmount"], net_amount_huf: [:decimal, "invoiceNetAmountHUF"],
        vat_amount: [:decimal, "invoiceVatAmount"], vat_amount_huf: [:decimal, "invoiceVatAmountHUF"],
        transaction_id: [:text, "transactionId"], index: [:integer, "index"],
        original_invoice_number: [:text, "originalInvoiceNumber"], modification_index: [:integer, "modificationIndex"],
        ins_date: [:time, "insDate"], completeness_indicator: [:boolean, "completenessIndicator"]
      }.freeze
      private_constant :DIGEST_FIELDS

      # @param direction [Symbol] `:outbound` or `:inbound`
      # @param page [Integer]
      # @param filters [Hash] see {Invoices#digest}
      # @raise [ArgumentError]
      def initialize(direction:, page: 1, **filters)
        super()
        @direction = Params.direction(direction)
        @page = Params.page(page)
        @query = InvoiceQueryParams.new(filters)
      end

      def name = "queryInvoiceDigest"
      def rate_limited? = false
      def auto_retry? = true

      def build_body(xml)
        xml.page @page
        xml.invoiceDirection @direction
        @query.build(xml)
      end

      # @return [Page<InvoiceDigest>]
      def parse(document, request_id:, raw_xml:)
        result = document.root.at_xpath("api:invoiceDigestResult", NAMESPACES)
        page(result, "api:invoiceDigest", request_id:, raw_xml:) { |node| digest(node) }
      end

      private

      def digest(node)
        values = DIGEST_FIELDS.transform_values { |(reader, element)| send(reader, node, "api:#{element}") }
        InvoiceDigest.new(**values)
      end
    end
  end
end
