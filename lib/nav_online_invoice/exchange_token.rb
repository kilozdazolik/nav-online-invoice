# frozen_string_literal: true

module NavOnlineInvoice
  ExchangeToken = Data.define(:value, :valid_from, :valid_to, :received_at)

  # A decrypted, single-use exchange token for one manageInvoice or manageAnnulment request.
  #
  # Its age is measured on the monotonic clock from when it arrived, so a wrong or jumping local clock does not
  # matter; only the length of NAV's validity window is taken from the answer.
  #
  # @api private
  class ExchangeToken
    include Redacted

    # Seconds kept in reserve for the request to reach NAV.
    MARGIN = 30

    # Whether the token is still valid for a request sent now.
    def fresh?(now = Monotonic.now)
      return false unless valid_from && valid_to

      (valid_to - valid_from) - (now - received_at) > MARGIN
    end

    # NAV's clock now, worked out from the token's validity start and the time since it arrived.
    #
    # @return [Time, nil]
    def nav_time(now = Monotonic.now)
      valid_from && (valid_from + (now - received_at))
    end

    # Leaves out the token, which `to_json` and `as_json` would otherwise include.
    def to_h(&) = super.merge(value: Redactor::FILTERED).to_h(&)

    # Leaves out the token.
    def inspect
      "#<data #{self.class.name} value=[FILTERED], valid_from=#{valid_from.inspect}, valid_to=#{valid_to.inspect}>"
    end
  end
end
