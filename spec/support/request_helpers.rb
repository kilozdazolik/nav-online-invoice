# frozen_string_literal: true

module RequestHelpers
  # Builds the full request XML of an operation with fixed request ID and time.
  def build_request(operation, config: build_config)
    NavOnlineInvoice::RequestBuilder.new(config).build(operation, request_id: "RID1", time: Time.utc(2026, 1, 1))
  end

  # The canonical elements after <software>: what an operation adds to the request.
  def request_body(xml)
    document = Nokogiri::XML(xml, &:noblanks)
    document.xpath("//comment()").remove
    document.root.at_xpath("api:software", NavOnlineInvoice::NAMESPACES)
            .xpath("following-sibling::*").map(&:canonicalize).join
  end
end

RSpec.configure do |config|
  config.include RequestHelpers
end
