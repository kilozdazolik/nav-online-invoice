# frozen_string_literal: true

module NavOnlineInvoice
  # Checks the list of invoices or annulments given to a submission.
  #
  # @api private
  module ItemList
    module_function

    # @param items [Array<Hash>]
    # @return [Array<Hash>]
    # @raise [ArgumentError] unless it is an Array of 1 to 100 Hashes
    def check(items)
      max = Operations::Manage::MAX_ITEMS
      return items if items.is_a?(Array) && items.all?(Hash) && items.size.between?(1, max)

      raise ArgumentError, "items must be an Array of 1-#{max} Hashes"
    end

    # @raise [ArgumentError] if the item has keys other than the allowed ones
    def known_keys!(name, item, allowed)
      unknown = item.keys - allowed
      raise ArgumentError, "#{name} has unknown keys: #{unknown.inspect}" unless unknown.empty?
    end
  end
end
