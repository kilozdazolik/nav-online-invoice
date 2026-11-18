# frozen_string_literal: true

module NavOnlineInvoice
  # One value of a service metric.
  #
  # @!attribute timestamp
  #   @return [Time] UTC
  # @!attribute value
  #   @return [BigDecimal]
  MetricValue = Data.define(:timestamp, :value)
end
