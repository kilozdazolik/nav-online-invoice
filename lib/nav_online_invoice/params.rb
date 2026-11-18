# frozen_string_literal: true

module NavOnlineInvoice
  # Converts Ruby values into NAV request values and rejects what NAV would refuse.
  #
  # Every method raises ArgumentError with the name of the keyword, so a bad argument fails before a request
  # is sent.
  #
  # @api private
  module Params
    module_function

    # Date ranges in invoice and transaction queries may span at most 35 days (spec 1.8.6.1, 1.8.7).
    MAX_DAYS = 35
    MAX_HOURS = 840

    # What a submitted invoice does: the same values in submissions and in invoice queries.
    INVOICE_OPERATIONS = %w[CREATE MODIFY STORNO].freeze

    def direction(value)
      enum(:direction, value, %w[INBOUND OUTBOUND])
    end

    # @return [String] the NAV value, e.g. :transfer => "TRANSFER"
    def enum(name, value, allowed)
      nav_value = value.to_s.upcase
      return nav_value if allowed.include?(nav_value)

      raise ArgumentError, "#{name} must be one of #{allowed.map { |v| ":#{v.downcase}" }.join(", ")}, " \
                           "got #{value.inspect}"
    end

    def page(value)
      positive_integer(:page, value)
    end

    def positive_integer(name, value)
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive Integer, got #{value.inspect}"
    end

    def index(name, value)
      return value if value.is_a?(Integer) && value.between?(1, 100)

      raise ArgumentError, "#{name} must be an Integer from 1 to 100, got #{value.inspect}"
    end

    def transaction_id(value)
      return value if value.is_a?(String) && value.match?(/\A[+a-zA-Z0-9_]{1,30}\z/)

      raise ArgumentError, "transaction_id must be 1-30 characters of letters, digits, + and _, got #{value.inspect}"
    end

    # The messages of this and {text} leave out the value, which can be personal data.
    def tax_number(name, value)
      TaxNumber.normalize(value)
    rescue ArgumentError
      raise ArgumentError, "#{name} must be a tax number with 8 or 11 digits"
    end

    def text(name, value, max:, min: 1)
      string = value.to_s
      return string if !string.strip.empty? && string.length.between?(min, max)

      raise ArgumentError, "#{name} must be #{min}-#{max} characters, not blank; got #{string.length}"
    end

    # @param range [Range<Date>] inclusive or exclusive
    # @return [Array(Date, Date)] the first and the last day
    def date_range(name, range)
      raise ArgumentError, "#{name} must be a Range of Dates" unless range.is_a?(Range) && date?(range.begin) &&
                                                                     date?(range.end)

      to = range.exclude_end? ? range.end - 1 : range.end
      bounds(name, range.begin, to, max: MAX_DAYS, limit: "#{MAX_DAYS} days")
    end

    # @param range [Range<Time>] inclusive; NAV's upper bound is inclusive too
    # @return [Array(Time, Time)] both in UTC
    def time_range(name, range)
      unless range.is_a?(Range) && time?(range.begin) && time?(range.end)
        raise ArgumentError, "#{name} must be a Range of Times"
      end
      raise ArgumentError, "#{name} must be an inclusive Range (a..b)" if range.exclude_end?

      bounds(name, range.begin.getutc, range.end.getutc, max: MAX_HOURS * 3600, limit: "#{MAX_HOURS} hours")
    end

    # @param max [Numeric] the largest allowed difference: days for Dates, seconds for Times
    def bounds(name, from, to, max:, limit:)
      raise ArgumentError, "#{name} starts after it ends" if from > to
      raise ArgumentError, "#{name} may span at most #{limit}" if (to - from) > max

      [from, to]
    end

    # @return [String] the timestamp format NAV expects, in UTC with milliseconds
    def timestamp(time)
      time.getutc.strftime("%Y-%m-%dT%H:%M:%S.%LZ")
    end

    # @return [String] an amount with two decimals, e.g. "1234.50"
    def amount(name, value)
      decimal = to_decimal(value)
      raise ArgumentError, "#{name} must be a number with at most 2 decimals, got #{value.inspect}" unless decimal

      whole, fraction = decimal.to_s("F").split(".")
      "#{whole}.#{fraction.to_s.ljust(2, "0")}"
    end

    # Turns a value into NAV relational conditions: a single value means EQ, a closed range GTE/LTE (or LT for an
    # exclusive end). NAV accepts no open ranges.
    #
    # @param kind [Symbol] `:date` or `:amount`
    # @return [Array<Array(String, String)>] operator and value pairs
    def relational(name, value, kind)
      return [["EQ", relational_value(name, value, kind)]] unless value.is_a?(Range)
      raise ArgumentError, "#{name} needs both a lower and an upper bound" if value.begin.nil? || value.end.nil?
      raise ArgumentError, "#{name} starts after it ends" if value.begin > value.end

      [["GTE", relational_value(name, value.begin, kind)],
       [value.exclude_end? ? "LT" : "LTE", relational_value(name, value.end, kind)]]
    end

    def relational_value(name, value, kind)
      return amount(name, value) if kind == :amount
      raise ArgumentError, "#{name} must be a Date or a Range of Dates, got #{value.inspect}" unless date?(value)

      value.iso8601
    end

    # @return [BigDecimal, nil] nil unless the value fits NAV's MonetaryType (18 digits, 2 of them decimals)
    def to_decimal(value)
      decimal = parse_decimal(value)
      decimal if decimal && decimal.round(2) == decimal && decimal.abs < 10**16
    end

    def parse_decimal(value)
      case value
      when Integer, BigDecimal, Rational then BigDecimal(value, 20)
      when Float then BigDecimal(value.to_s)
      when String then BigDecimal(value) if value.match?(/\A-?\d+(\.\d+)?\z/)
      end
    end

    def date?(value)
      value.is_a?(Date) && !value.is_a?(DateTime)
    end

    # @return [Time]
    def time(name, value)
      return value if time?(value)

      raise ArgumentError, "#{name} must be a Time, got #{value.inspect}"
    end

    def time?(value)
      value.respond_to?(:getutc) && !value.is_a?(Date)
    end
  end
end
