# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Lists an invoice and all its modifications.
    class QueryInvoiceChainDigest < Base
      # @param invoice_number [String] the original invoice
      # @param direction [Symbol] +:outbound+ or +:inbound+
      # @param tax_number [String, nil] the other party's tax number
      # @param page [Integer]
      # @raise [ArgumentError]
      def initialize(invoice_number, direction:, tax_number: nil, page: 1)
        super()
        @invoice_number = Params.text(:invoice_number, invoice_number, max: 50)
        @direction = Params.direction(direction)
        @tax_number = tax_number && Params.tax_number(:tax_number, tax_number)
        @page = Params.page(page)
      end

      def name = "queryInvoiceChainDigest"
      def rate_limited? = false
      def auto_retry? = true

      def build_body(xml)
        xml.page @page
        xml.invoiceChainQuery do
          xml.invoiceNumber @invoice_number
          xml.invoiceDirection @direction
          xml.taxNumber @tax_number if @tax_number
        end
      end

      # @return [Page<InvoiceChainElement>]
      def parse(document, request_id:, raw_xml:)
        result = document.root.at_xpath("api:invoiceChainDigestResult", NAMESPACES)
        Page.new(
          request_id: request_id,
          current_page: integer(result, "api:currentPage"),
          total_pages: integer(result, "api:availablePage"),
          items: result.xpath("api:invoiceChainElement", NAMESPACES).map { |node| element(node) },
          raw_xml: raw_xml
        )
      end

      private

      def element(node)
        digest = node.at_xpath("api:invoiceChainDigest", NAMESPACES)
        InvoiceChainElement.new(
          invoice_number: text(digest, "api:invoiceNumber"),
          batch_index: integer(digest, "api:batchIndex"),
          operation: symbol(digest, "api:invoiceOperation"),
          supplier_tax_number: text(digest, "api:supplierTaxNumber"),
          customer_tax_number: text(digest, "api:customerTaxNumber"),
          ins_date: time(digest, "api:insDate"),
          original_request_version: text(digest, "api:originalRequestVersion"),
          max_line_number: integer(node, "api:invoiceLines/api:maxLineNumber"),
          new_created_lines: new_created_lines(node),
          reference: reference(node.at_xpath("api:invoiceReferenceData", NAMESPACES))
        )
      end

      def new_created_lines(node)
        node.xpath("api:invoiceLines/api:newCreatedLines", NAMESPACES).map do |lines|
          integer(lines, "api:lineNumberIntervalStart")..integer(lines, "api:lineNumberIntervalEnd")
        end
      end

      def reference(node)
        return unless node

        InvoiceReference.new(
          original_invoice_number: text(node, "api:originalInvoiceNumber"),
          modify_without_master: boolean(node, "api:modifyWithoutMaster"),
          modification_timestamp: time(node, "api:modificationTimestamp"),
          modification_index: integer(node, "api:modificationIndex")
        )
      end
    end
  end
end
