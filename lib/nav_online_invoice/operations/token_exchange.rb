# frozen_string_literal: true

module NavOnlineInvoice
  module Operations
    # Requests a single-use exchange token for a submission (spec 1.8.10).
    class TokenExchange < Base
      # @param exchange_key [String] decrypts the token NAV sends
      def initialize(exchange_key)
        super()
        @exchange_key = exchange_key
      end

      def name = "tokenExchange"

      # Changes no data; an unused token simply expires.
      def auto_retry? = true

      def build_body(_xml); end

      # @return [ExchangeToken]
      # @raise [DecodeError] if the token does not decrypt with the exchange key
      def parse(document, **)
        root = document.root
        ExchangeToken.new(
          value: Crypto.decrypt_token(text(root, "api:encodedExchangeToken"), @exchange_key),
          valid_from: time(root, "api:tokenValidityFrom"),
          valid_to: time(root, "api:tokenValidityTo"),
          received_at: Monotonic.now
        )
      end
    end
  end
end
