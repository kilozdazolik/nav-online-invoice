# frozen_string_literal: true

module NavOnlineInvoice
  # Hashes and signatures required by the NAV API.
  module Crypto
    module_function

    # Returns the passwordHash value: the SHA-512 of the password, as uppercase hex.
    #
    # @param password [String]
    # @return [String]
    def password_hash(password)
      OpenSSL::Digest.new("SHA512").hexdigest(password).upcase
    end

    # Returns the requestSignature value.
    #
    # The signature is the SHA3-512 of the request ID, the timestamp (UTC, yyyyMMddHHmmss) and the
    # signature key. Invoice submissions append one index hash per invoice.
    #
    # @param request_id [String]
    # @param time [Time] the same time that is written into the request header
    # @param signature_key [String]
    # @param index_hashes [Array<String>] results of {index_hash}, in index order
    # @return [String]
    def request_signature(request_id, time, signature_key, index_hashes: [])
      sha3("#{request_id}#{time.getutc.strftime("%Y%m%d%H%M%S")}#{signature_key}#{index_hashes.join}")
    end

    # Returns the hash of one invoice in a manageInvoice or manageAnnulment request.
    #
    # @param operation [String] e.g. "CREATE"
    # @param base64_data [String] the invoice data exactly as sent, Base64 encoded
    # @return [String]
    def index_hash(operation, base64_data)
      sha3("#{operation}#{base64_data}")
    end

    def sha3(value)
      OpenSSL::Digest.new("SHA3-512").hexdigest(value).upcase
    end
    private_class_method :sha3
  end
end
