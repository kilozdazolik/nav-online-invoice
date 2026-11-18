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

    # Decrypts the exchange token that tokenExchange returns.
    #
    # @param encoded [String] the encodedExchangeToken value, Base64
    # @param exchange_key [String] the technical user's exchange key
    # @return [String] the token to send in manageInvoice and manageAnnulment
    # @raise [DecodeError] if the token cannot be decrypted with this key
    def decrypt_token(encoded, exchange_key)
      cipher = OpenSSL::Cipher.new("AES-128-ECB").decrypt
      cipher.key = exchange_key
      bytes = encoded.to_s.delete(" \t\r\n").unpack1("m0")
      token = (cipher.update(bytes) + cipher.final).force_encoding(Encoding::UTF_8)
      # A wrong key passes the padding check now and then, so the result is checked as well.
      return token if token.valid_encoding? && token.match?(/\A[[:graph:]]{1,50}\z/)

      raise DecodeError, "the exchange token could not be decrypted; check exchange_key"
    rescue OpenSSL::Cipher::CipherError, ArgumentError
      raise DecodeError, "the exchange token could not be decrypted; check exchange_key"
    end

    def sha3(value)
      OpenSSL::Digest.new("SHA3-512").hexdigest(value).upcase
    end
    private_class_method :sha3
  end
end
