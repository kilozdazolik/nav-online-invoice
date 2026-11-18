# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # What manageInvoice and manageAnnulment share: a single-use token, up to 100 items signed with their index
    # hashes, and a transaction ID as the answer.
    #
    # Never retried automatically: a submission without an answer may already be at NAV.
    class Manage < Base
      MAX_ITEMS = 100
      # The whole request, in bytes (spec 1.6.5).
      MAX_BODY_BYTES = 10_000_000

      # One invoice or annulment, encoded exactly as it is sent.
      #
      # @!attribute operation
      #   @return [String] "CREATE", "MODIFY", "STORNO" or "ANNUL"
      # @!attribute data
      #   @return [String] the XML, base64 and maybe gzipped; the index hash is computed from this string
      # @!attribute electronic_invoice_hash
      #   @return [ElectronicInvoiceHash, nil] invoices only
      Item = Data.define(:operation, :data, :electronic_invoice_hash) do
        include Redacted

        def initialize(operation:, data:, electronic_invoice_hash: nil)
          super
        end

        # Leaves out the data.
        def inspect = "#<data #{self.class.name} operation=#{operation.inspect}, data=[#{data.bytesize} bytes]>"

        # Leaves out the data, which `to_json` and `as_json` would otherwise include.
        def to_h(&) = super.merge(data: "[FILTERED #{data.bytesize} bytes]").to_h(&)
      end

      # @param token [ExchangeToken]
      # @param items [Array<Item>] in index order
      def initialize(token:, items:)
        super()
        unless items.size.between?(1, MAX_ITEMS)
          raise ArgumentError, "a submission takes 1-#{MAX_ITEMS} items, got #{items.size}"
        end

        @token = token
        @items = items.dup.freeze
        @index_hashes = @items.map { |item| Crypto.index_hash(item.operation, item.data) }.freeze
      end

      attr_reader :index_hashes, :sent_at

      def submission? = true
      def max_body_bytes = MAX_BODY_BYTES

      # Also notes the time of sending by NAV's clock, which a lost answer is reconciled against.
      #
      # @raise [ExchangeTokenError] if the token expired while the request waited
      def check_before_send!
        unless @token.fresh?
          raise ExchangeTokenError.new(code: nil, nav_message: "the exchange token expired before the request was sent")
        end

        @sent_at = @token.nav_time
      end

      # @return [Submission] NAV processes the items afterwards
      def parse(document, request_id:, **)
        Submission.new(transaction_id: text(document.root, "api:transactionId"), request_id:,
                       item_count: @items.size, compressed: compressed?,
                       electronic_invoice_hashes: @items.map(&:electronic_invoice_hash))
      end

      # Leaves out the token and the items.
      def inspect = "#<#{self.class.name} items=#{@items.size}>"

      private

      def compressed? = false
    end
  end
end
