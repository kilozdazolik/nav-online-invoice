# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Submits up to 100 invoices with one exchange token (spec 1.8.2).
    #
    # Never retried automatically: a submission without an answer may already be at NAV.
    class ManageInvoice < Base
      MAX_ITEMS = 100
      # The whole request, in bytes (spec 1.6.5).
      MAX_BODY_BYTES = 10_000_000

      # One invoice, encoded exactly as it is sent.
      #
      # @!attribute operation
      #   @return [String] "CREATE", "MODIFY" or "STORNO"
      # @!attribute data
      #   @return [String] the invoice XML, base64 and maybe gzipped; the index hash is computed from this string
      # @!attribute electronic_invoice_hash
      #   @return [Hash, nil] +{ value:, crypto_type: }+
      Item = Data.define(:operation, :data, :electronic_invoice_hash) do
        # Leaves out the invoice data.
        def inspect = "#<data #{self.class.name} operation=#{operation.inspect}, data=[#{data.bytesize} bytes]>"
        alias_method :to_s, :inspect
      end

      # @param token [ExchangeToken]
      # @param items [Array<Item>] in index order
      # @param compressed [Boolean] whether the data of every item is gzipped
      def initialize(token:, items:, compressed:)
        super()
        unless items.size.between?(1, MAX_ITEMS)
          raise ArgumentError, "a submission takes 1-#{MAX_ITEMS} invoices, got #{items.size}"
        end

        @token = token
        @items = items.dup.freeze
        @compressed = compressed
        @index_hashes = @items.map { |item| Crypto.index_hash(item.operation, item.data) }.freeze
      end

      attr_reader :index_hashes

      def name = "manageInvoice"
      def submission? = true
      def max_body_bytes = MAX_BODY_BYTES

      # @raise [ExchangeTokenError] if the token expired while the request waited
      def check_before_send!
        return if @token.fresh?

        raise ExchangeTokenError.new(code: nil, nav_message: "the exchange token expired before the request was sent")
      end

      def build_body(xml)
        xml.exchangeToken @token.value
        xml.invoiceOperations do
          xml.compressedContent @compressed
          @items.each.with_index(1) { |item, index| build_item(xml, item, index) }
        end
      end

      # @return [Submission] NAV processes the invoices afterwards
      def parse(document, request_id:, **)
        Submission.new(transaction_id: text(document.root, "api:transactionId"), request_id:,
                       item_count: @items.size, compressed: @compressed,
                       electronic_invoice_hashes: @items.map { |item| item.electronic_invoice_hash&.fetch(:value) })
      end

      # Leaves out the token and the invoices.
      def inspect = "#<#{self.class.name} items=#{@items.size}>"

      private

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
