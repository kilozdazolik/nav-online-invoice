# frozen_string_literal: true

module NavOnlineInvoice
  # Sends request XML to NAV over HTTPS.
  #
  # @api private
  class Transport
    # The HTTP status and body of NAV's answer.
    Response = Data.define(:status, :body)

    NETWORK_ERRORS = [
      Timeout::Error, SocketError, SystemCallError, IOError, EOFError, OpenSSL::SSL::SSLError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Zlib::Error
    ].freeze
    private_constant :NETWORK_ERRORS

    def initialize(open_timeout:, read_timeout:, write_timeout:)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
    end

    # @param uri [URI::HTTPS]
    # @param body [String] the request XML
    # @return [Response]
    # @raise [TransportError] if no answer arrived
    def post(uri, body)
      response = http(uri).start { |connection| connection.request(request(uri, body)) }
      Response.new(status: response.code.to_i, body: response.body.to_s.dup.force_encoding(Encoding::UTF_8))
    rescue *NETWORK_ERRORS => e
      raise transport_error(e)
    end

    private

    def transport_error(error)
      # A certificate that cannot be verified will not fix itself on retry.
      certificate = error.is_a?(OpenSSL::SSL::SSLError) && error.message.include?("certificate verify failed")
      TransportError.new("#{error.class}: #{error.message}", retryable: !certificate)
    end

    def http(uri)
      Net::HTTP.new(uri.host, uri.port).tap do |http|
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = @open_timeout
        http.read_timeout = @read_timeout
        http.write_timeout = @write_timeout
        # Never let Net::HTTP send the request again: NAV needs a new request ID on every attempt.
        http.max_retries = 0
      end
    end

    def request(uri, body)
      Net::HTTP::Post.new(uri).tap do |request|
        request["Content-Type"] = "application/xml; charset=UTF-8"
        request["Accept"] = "application/xml"
        request["User-Agent"] = "nav_online_invoice/#{VERSION} Ruby/#{RUBY_VERSION}"
        request.body = body
      end
    end
  end
end
