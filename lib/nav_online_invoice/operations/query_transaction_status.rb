# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Asks how NAV processed a submission.
    class QueryTransactionStatus < Base
      # @param transaction_id [String] the ID NAV returned for the submission
      # @param return_original_request [Boolean] also return the submitted invoices
      # @raise [ArgumentError]
      def initialize(transaction_id, return_original_request: false)
        super()
        @transaction_id = Params.transaction_id(transaction_id)
        @return_original_request = return_original_request ? true : false
      end

      def name = "queryTransactionStatus"

      # Rate limited: the spec's list (1.6.11, "v1 endpoints") names it by its old name, /queryInvoiceStatus.
      def rate_limited? = true
      def auto_retry? = true

      def build_body(xml)
        xml.transactionId @transaction_id
        xml.returnOriginalRequest @return_original_request
      end

      # @return [TransactionStatus, nil] nil if NAV knows no such transaction
      # @raise [DecodeError] if a returned original request cannot be decoded
      def parse(document, request_id:, raw_xml:)
        list = document.root.at_xpath("api:processingResults", NAMESPACES)
        return unless list

        TransactionStatus.new(
          request_id:,
          results: list.xpath("api:processingResult", NAMESPACES).map { |node| result(node) },
          original_request_version: text(list, "api:originalRequestVersion"),
          annulment_verification_status: symbol(list, "api:annulmentData/api:annulmentVerificationStatus"),
          annulment_decision_date: time(list, "api:annulmentData/api:annulmentDecisionDate"),
          annulment_decision_user: text(list, "api:annulmentData/api:annulmentDecisionUser"),
          raw_xml:
        )
      end

      private

      def result(node)
        compressed = boolean(node, "api:compressedContentIndicator")
        original = text(node, "api:originalRequest")
        ProcessingResult.new(
          index: integer(node, "api:index"),
          batch_index: integer(node, "api:batchIndex"),
          status: symbol(node, "api:invoiceStatus"),
          technical_validation_messages: technical_validation_messages(node),
          business_validation_messages: node.xpath("api:businessValidationMessages", NAMESPACES).map do |message|
            business_message(message)
          end,
          compressed:,
          original_request: original && Payload.decode(original, compressed:)
        )
      end

      def business_message(node)
        BusinessValidationMessage.new(
          result_code: symbol(node, "api:validationResultCode"),
          error_code: text(node, "api:validationErrorCode"),
          message: text(node, "api:message"),
          tag: text(node, "api:pointer/api:tag"),
          value: text(node, "api:pointer/api:value"),
          line: integer(node, "api:pointer/api:line"),
          original_invoice_number: text(node, "api:pointer/api:originalInvoiceNumber")
        )
      end
    end
  end
end
