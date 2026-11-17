# frozen_string_literal: true

module NavOnlineInvoice
  # Validates XML against NAV's official schemas.
  #
  # Each schema is loaded once, on first use, from the copies in the gem's schemas/ directory.
  module SchemaValidator
    SCHEMA_DIR = File.expand_path("../../schemas", __dir__)

    # +:api+ for requests and responses, +:data+ for invoices in the 3.0 format.
    SCHEMAS = { api: "invoiceApi.xsd", data: "invoiceData.xsd" }.freeze

    @mutex = Mutex.new
    @schemas = {}

    class << self
      # Checks the XML against a schema.
      #
      # @param xml [String]
      # @param schema [Symbol] +:api+ or +:data+
      # @return [String] the same XML
      # @raise [SchemaValidationError] if the XML does not match the schema
      def validate!(xml, schema: :api)
        errors = self.errors(xml, schema:)
        raise SchemaValidationError, errors unless errors.empty?

        xml
      end

      # Returns the schema violations in the XML.
      #
      # @param xml [String]
      # @param schema [Symbol] +:api+ or +:data+
      # @return [Array<String>] empty if the XML is valid
      def errors(xml, schema: :api)
        document, syntax_error = parse(xml)
        return [syntax_error] if syntax_error

        load_schema(schema).validate(document).map(&:message)
      end

      private

      def parse(xml)
        [Nokogiri::XML(xml) { |config| config.strict.nonet }, nil]
      rescue Nokogiri::XML::SyntaxError => e
        [nil, e.message]
      end

      def load_schema(name)
        file = SCHEMAS.fetch(name) { raise ArgumentError, "schema must be one of #{SCHEMAS.keys.inspect}" }
        @schemas[name] || @mutex.synchronize do
          path = File.join(SCHEMA_DIR, file)
          # The document URL lets libxml2 resolve the relative schemaLocation of the imports.
          @schemas[name] ||= Nokogiri::XML::Schema.from_document(Nokogiri::XML(File.read(path), path))
        end
      end
    end
  end
end
