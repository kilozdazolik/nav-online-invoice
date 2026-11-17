# frozen_string_literal: true

module NavOnlineInvoice
  # One class per NAV operation: what to send and how to read the answer.
  #
  # @api private
  module Operations
    # The contract between an operation and {Client#execute}.
    #
    # A subclass defines {#name}, {#build_body} and {#parse}, and validates its arguments in +initialize+, so a
    # bad argument fails before any request is built.
    class Base
      include XmlReader

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

      # Writes the operation's elements after the shared header, user and software parts.
      #
      # @param xml [Nokogiri::XML::Builder]
      def build_body(xml)
        raise NotImplementedError, "#{self.class} must define build_body"
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
