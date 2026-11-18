# frozen_string_literal: true

module NavOnlineInvoice
  # A schema violation NAV found in a request (in an error answer) or in a submitted invoice (in its status).
  #
  # @!attribute result_code
  #   @return [Symbol] `:error` or `:critical`
  # @!attribute error_code
  #   @return [String, nil]
  # @!attribute message
  #   @return [String, nil] the element, its value and the expected value
  TechnicalValidationMessage = Data.define(:result_code, :error_code, :message)
end
