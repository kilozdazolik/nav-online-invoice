# frozen_string_literal: true

module NavOnlineInvoice
  # A service metric with its values of the last hour, one per minute.
  #
  # @!attribute type
  #   @return [Symbol] `:counter`, `:gauge`, `:histogram` or `:summary`
  # @!attribute descriptions
  #   @return [Hash{Symbol => String}] by language: `:hu`, `:en` and `:de`
  # @!attribute values
  #   @return [Array<MetricValue>] oldest first; empty while NAV has no data
  Metric = Data.define(:name, :type, :descriptions, :values)
end
