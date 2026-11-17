# frozen_string_literal: true

module NavOnlineInvoice
  # Queries about submissions to NAV. Use through {Client#transactions}.
  class Transactions
    # @api private
    def initialize(client)
      @client = client
    end

    # Lists the submissions NAV received in a time range, one page at a time.
    #
    # Useful to find a transaction ID that was lost, e.g. after a timeout.
    #
    # @example
    #   page = client.transactions.list(ins_date: (Time.now - 86_400)..Time.now)
    #   page.each { |transaction| puts transaction.transaction_id }
    # @param ins_date [Range<Time>] inclusive; at most 840 hours (35 days)
    # @param status [Symbol, nil] +:received+, +:processing+, +:saved+, +:finished+ or +:notified+
    # @param page [Integer]
    # @return [Page<Transaction>]
    # @raise [ArgumentError] if a parameter is invalid
    def list(ins_date:, status: nil, page: 1)
      @client.execute(Operations::QueryTransactionList.new(ins_date:, status:, page:))
    end

    # Walks all pages of {#list}, fetching each page only when it is reached.
    #
    # @param max_pages [Integer, nil] stop after this many pages
    # @yieldparam transaction [Transaction]
    # @return [Enumerator<Transaction>] if no block is given
    def each_transaction(ins_date:, status: nil, max_pages: nil, &)
      items = Paging.items(max_pages) { |page| list(ins_date:, status:, page:) }
      block_given? ? items.each(&) : items
    end
  end
end
