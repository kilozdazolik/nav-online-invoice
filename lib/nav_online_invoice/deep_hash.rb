# frozen_string_literal: true

module NavOnlineInvoice
  # Makes `to_h` turn nested records and arrays of records into hashes too, so the result can be written as JSON.
  # `Data#to_h` alone stops at the first level.
  #
  # @api private
  module DeepHash
    def self.convert(value)
      case value
      when Data then value.to_h.transform_values { |nested| convert(nested) }
      when Array then value.map { |nested| convert(nested) }
      else value
      end
    end

    def to_h(&)
      hash = super().transform_values { |value| DeepHash.convert(value) }
      block_given? ? hash.to_h(&) : hash
    end
  end
end
