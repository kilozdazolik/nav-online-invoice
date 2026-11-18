# frozen_string_literal: true

module NavOnlineInvoice
  Page = Data.define(:request_id, :current_page, :total_pages, :items, :raw_xml)

  # One page of a paged NAV query.
  #
  # @!attribute current_page
  #   @return [Integer] starting at 1
  # @!attribute total_pages
  #   @return [Integer] 0 if nothing matched
  # @!attribute items
  #   @return [Array] the results on this page
  # @!attribute raw_xml
  #   @return [String] NAV's answer; it can hold names, addresses and invoice contents, so do not log it
  class Page
    include Redacted

    def initialize(request_id:, current_page:, total_pages:, items:, raw_xml:)
      super(request_id:, current_page:, total_pages:, items: items.dup.freeze, raw_xml:)
    end

    # Whether no further page follows.
    def last_page?
      current_page >= total_pages
    end

    # Whether nothing is on this page.
    def empty?
      items.empty?
    end

    # The number of items on this page.
    def size
      items.size
    end

    # Yields each item on this page; see {Paging} for all pages.
    def each(&)
      items.each(&)
    end

    # Shows the page numbers and the item count; the items can hold names and amounts.
    def inspect
      "#<data #{self.class.name} request_id=#{request_id.inspect}, current_page=#{current_page}, " \
        "total_pages=#{total_pages}, items=#{size}>"
    end
  end
end
