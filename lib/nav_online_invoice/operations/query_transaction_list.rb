# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Lists the submissions received in a time range.
    class QueryTransactionList < Base
      STATUSES = %w[RECEIVED PROCESSING SAVED FINISHED NOTIFIED].freeze

      # @param ins_date [Range<Time>] when NAV received them; at most 840 hours
      # @param status [Symbol, nil] only submissions in this state
      # @param page [Integer]
      # @raise [ArgumentError]
      def initialize(ins_date:, status: nil, page: 1)
        super()
        @from, @to = Params.time_range(:ins_date, ins_date)
        @status = status && Params.enum(:status, status, STATUSES)
        @page = Params.page(page)
      end

      def name = "queryTransactionList"
      def rate_limited? = false
      def auto_retry? = true

      def build_body(xml)
        xml.page @page
        xml.insDate do
          xml.dateTimeFrom Params.timestamp(@from)
          xml.dateTimeTo Params.timestamp(@to)
        end
        xml.requestStatus @status if @status
      end

      # @return [Page<Transaction>]
      def parse(document, request_id:, raw_xml:)
        result = document.root.at_xpath("api:transactionListResult", NAMESPACES)
        page(result, "api:transaction", request_id:, raw_xml:) { |node| transaction(node) }
      end

      private

      def transaction(node)
        Transaction.new(
          transaction_id: text(node, "api:transactionId"),
          ins_date: time(node, "api:insDate"),
          ins_cus_user: text(node, "api:insCusUser"),
          source: symbol(node, "api:source"),
          status: symbol(node, "api:requestStatus"),
          technical_annulment: boolean(node, "api:technicalAnnulment"),
          original_request_version: text(node, "api:originalRequestVersion"),
          item_count: integer(node, "api:itemCount")
        )
      end
    end
  end
end
