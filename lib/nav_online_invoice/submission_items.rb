# frozen_string_literal: true

module NavOnlineInvoice
  # Checks and encodes the invoices of a submission before any request is sent.
  #
  # @api private
  module SubmissionItems
    OPERATIONS = %w[CREATE MODIFY STORNO].freeze
    KEYS = %i[operation xml electronic_invoice_hash].freeze
    # The largest invoice NAV accepts, uncompressed (spec 1.6.5).
    MAX_INVOICE_BYTES = 15_000_000
    # Header, token and element names of a request, with room to spare.
    OVERHEAD_BYTES = 5_000
    ITEM_OVERHEAD_BYTES = 500
    HASH_LENGTHS = { "SHA3-512" => 128, "SHA-256" => 64 }.freeze

    Invoice = Data.define(:operation, :xml, :electronic_invoice_hash, :complete)
    private_constant :Invoice

    module_function

    # @param items [Array<Hash>]
    # @param compress [Boolean, :auto]
    # @param validate [Boolean] check each invoice against the invoiceData schema
    # @return [Array(Array<Operations::Manage::Item>, Boolean)] the items and whether they are compressed
    # @raise [ArgumentError, SchemaValidationError, SubmissionTooLargeError]
    def prepare(items, compress:, validate:)
      unless items.is_a?(Array) && items.all?(Hash) && items.size.between?(1, Operations::Manage::MAX_ITEMS)
        raise ArgumentError, "items must be an Array of 1-#{Operations::Manage::MAX_ITEMS} Hashes"
      end

      invoices = items.map.with_index(1) { |item, index| invoice(item, "items[#{index}]", validate) }
      compressed = compress?(invoices, compress)
      [invoices.map { |invoice| encode(invoice, compressed) }, compressed]
    end

    def invoice(item, name, validate)
      unknown = item.keys - KEYS
      raise ArgumentError, "#{name} has unknown keys: #{unknown.inspect}" unless unknown.empty?

      xml = xml(item[:xml], name)
      SchemaValidator.validate!(xml, schema: :data) if validate
      document = Nokogiri::XML(xml)
      complete = document.at_xpath("/*/*[local-name()='completenessIndicator']")&.text == "true"
      Invoice.new(operation: Params.enum(:"#{name}[:operation]", item[:operation], OPERATIONS), xml:,
                  electronic_invoice_hash: electronic_invoice_hash(item[:electronic_invoice_hash], name, complete),
                  complete:)
    end

    def xml(value, name)
      unless value.is_a?(String) && value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
        raise ArgumentError, "#{name}[:xml] must be the invoice XML as a UTF-8 String"
      end
      if value.bytesize > MAX_INVOICE_BYTES
        raise SubmissionTooLargeError, "#{name} is #{value.bytesize} bytes; NAV accepts at most #{MAX_INVOICE_BYTES}"
      end

      value
    end

    # With completenessIndicator the hash is computed from the sent data, so only SHA3-512 may be given.
    def electronic_invoice_hash(value, name, complete)
      return nil if value.nil?

      unless value.is_a?(Hash) && HASH_LENGTHS.key?(value[:crypto_type]) &&
             value[:value].to_s.match?(/\A\h{#{HASH_LENGTHS[value[:crypto_type]]}}\z/)
        raise ArgumentError, "#{name}[:electronic_invoice_hash] must be { value:, crypto_type: } with a " \
                             "SHA3-512 or SHA-256 hex digest"
      end
      if complete && value[:crypto_type] != "SHA3-512"
        raise ArgumentError, "#{name}: an invoice with completenessIndicator needs a SHA3-512 hash"
      end

      { value: value[:value].upcase, crypto_type: value[:crypto_type] }
    end

    # Compresses only when needed: NAV queues compressed requests last (spec 1.6.5). An electronic invoice is
    # never compressed, since its hash is computed from the data as sent.
    def compress?(invoices, compress)
      raise ArgumentError, "compress must be true, false or :auto" unless [true, false, :auto].include?(compress)

      complete = invoices.any?(&:complete)
      raise ArgumentError, "invoices with completenessIndicator cannot be compressed" if compress == true && complete
      return compress unless compress == :auto

      !complete && estimated_bytes(invoices) > Operations::Manage::MAX_BODY_BYTES
    end

    def estimated_bytes(invoices)
      OVERHEAD_BYTES + invoices.sum { |invoice| ITEM_OVERHEAD_BYTES + (((invoice.xml.bytesize + 2) / 3) * 4) }
    end

    def encode(invoice, compressed)
      data = Payload.encode(invoice.xml, compressed:)
      Operations::Manage::Item.new(operation: invoice.operation, data:,
                                   electronic_invoice_hash: hash_for(invoice, data))
    end

    def hash_for(invoice, data)
      return invoice.electronic_invoice_hash unless invoice.complete

      computed = Crypto.electronic_invoice_hash(data)
      given = invoice.electronic_invoice_hash
      if given && given[:value] != computed
        raise ArgumentError, "electronic_invoice_hash does not match the invoice data; leave it out to have it computed"
      end

      { value: computed, crypto_type: "SHA3-512" }
    end
  end
end
