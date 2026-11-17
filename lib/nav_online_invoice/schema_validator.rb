# frozen_string_literal: true

module NavOnlineInvoice
  # Validates XML against NAV's official API schema.
  #
  # The schema is loaded once, on first use, from the copies in the gem's schemas/ directory.
  module SchemaValidator
    SCHEMA_PATH = File.expand_path("../../schemas/invoiceApi.xsd", __dir__)

    @mutex = Mutex.new

    class << self
      # Checks the XML against the schema.
      #
      # @param xml [String]
      # @return [String] the same XML
      # @raise [SchemaValidationError] if the XML does not match the schema
      def validate!(xml)
        errors = self.errors(xml)
        raise SchemaValidationError, errors unless errors.empty?

        xml
      end

      # Returns the schema violations in the XML.
      #
      # @param xml [String]
      # @return [Array<String>] empty if the XML is valid
      def errors(xml)
        document, syntax_error = parse(xml)
        return [syntax_error] if syntax_error

        schema.validate(document).map(&:message)
      end

      private

      def parse(xml)
        [Nokogiri::XML(xml) { |config| config.strict.nonet }, nil]
      rescue Nokogiri::XML::SyntaxError => e
        [nil, e.message]
      end

      def schema
        @schema || @mutex.synchronize do
          # The document URL lets libxml2 resolve the relative schemaLocation of the imports.
          @schema ||= Nokogiri::XML::Schema.from_document(Nokogiri::XML(File.read(SCHEMA_PATH), SCHEMA_PATH))
        end
      end
    end
  end
end
