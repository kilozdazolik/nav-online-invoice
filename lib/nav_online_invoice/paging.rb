# frozen_string_literal: true

module NavOnlineInvoice
  # Walks the pages of a paged query lazily.
  #
  # @api private
  module Paging
    module_function

    # @param max_pages [Integer, nil] stop after this many pages; nil for no limit
    # @yieldparam page_number [Integer]
    # @yieldreturn [Page]
    # @return [Enumerator] the items of all pages, fetched only as far as they are read
    def items(max_pages, &fetch_page)
      Params.positive_integer(:max_pages, max_pages) unless max_pages.nil?

      Enumerator.new do |yielder|
        number = 1
        loop do
          page = fetch_page.call(number)
          page.each { |item| yielder << item }
          break if page.last_page? || (max_pages && number >= max_pages)

          number += 1
        end
      end
    end
  end
end
