# frozen_string_literal: true

module NavOnlineInvoice
  # Makes `to_s`, `pp`, IRB and the Rails console show the class's own `inspect`, which leaves out secrets,
  # personal data and invoice contents. Without it, `pp` would print every field.
  #
  # @api private
  module Redacted
    def to_s = inspect

    def pretty_print(printer)
      printer.text(inspect)
    end
  end
end
