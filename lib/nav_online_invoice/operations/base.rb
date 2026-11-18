# frozen_string_literal: true

module NavOnlineInvoice
  # One class per NAV operation: what to send and how to read the answer.
  #
  # @api private
  module Operations
    # The contract between an operation and {Client#execute}.
    #
    # A subclass defines {#name}, {#build_body} and {#parse}, and validates its arguments in `initialize`, so a
    # bad argument fails before any request is built.
    class Base
      include XmlReader
      include Redacted

      # The NAV operation name, which is also the last part of its URL, e.g. "queryTaxpayer".
      def name
        raise NotImplementedError, "#{self.class} must define name"
      end

      def request_root = "#{name[0].upcase}#{name[1..]}Request"
      def response_root = "#{name[0].upcase}#{name[1..]}Response"

      # Whether NAV limits this operation to one request per second per IP address.
      #
      # True unless a subclass says otherwise: an unneeded wait costs at most a second, a missing one makes
      # NAV delay and drop requests.
      def rate_limited? = true

      # Whether a temporary failure may be retried automatically.
      #
      # False unless a subclass says otherwise, because an operation that changes data must never be sent twice.
      def auto_retry? = false

      # Whether the operation submits data. A submission without an answer raises {UnknownOutcomeError}.
      def submission? = false

      # The largest request NAV accepts for this operation, in bytes, or nil for no limit.
      def max_body_bytes = nil

      # Runs right before the request is sent, after the throttle; raises to stop it.
      def check_before_send!; end

      # When the request was sent by NAV's clock, if the operation knows it; see {UnknownOutcomeError#sent_at}.
      #
      # @return [Time, nil]
      def sent_at = nil

      # The hashes of the submitted items that are part of the request signature, in index order (spec 1.5.1).
      #
      # @return [Array<String>] empty for every operation but manageInvoice and manageAnnulment
      def index_hashes = []

      # Writes the operation's elements after the shared header, user and software parts.
      #
      # @param xml [Nokogiri::XML::Builder]
      def build_body(xml)
        raise NotImplementedError, "#{self.class} must define build_body"
      end

      # Shows only the operation, never its parameters, tokens or keys.
      def inspect = "#<#{self.class.name}>"

      # Builds a {Page} from the paging elements of an answer and the items read by the block.
      #
      # @param result [Nokogiri::XML::Node] the element with currentPage and availablePage
      # @param item_xpath [String] the items, relative to `result`
      # @yieldparam node [Nokogiri::XML::Node] one item
      # @return [Page]
      def page(result, item_xpath, request_id:, raw_xml:, &)
        Page.new(request_id:, current_page: integer(result, "api:currentPage"),
                 total_pages: integer(result, "api:availablePage"),
                 items: result.xpath(item_xpath, NAMESPACES).map(&), raw_xml:)
      end

      # Reads a successful answer.
      #
      # @param document [Nokogiri::XML::Document]
      # @param request_id [String]
      # @param raw_xml [String]
      def parse(document, request_id:, raw_xml:)
        raise NotImplementedError, "#{self.class} must define parse"
      end
    end
  end
end
