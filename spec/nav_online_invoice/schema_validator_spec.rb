# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::SchemaValidator do
  let(:official_request) { fixture("requests/query_taxpayer_official.xml") }

  it "accepts NAV's official sample request" do
    expect(described_class.validate!(official_request)).to eq(official_request)
  end

  it "reports a tax number with the wrong length" do
    invalid = official_request.sub("<taxNumber>22222222</taxNumber>", "<taxNumber>2222222</taxNumber>")

    expect { described_class.validate!(invalid) }.to raise_error(NavOnlineInvoice::SchemaValidationError) { |error|
      expect(error.errors.join).to include("taxNumber")
    }
  end

  it "reports malformed XML" do
    expect(described_class.errors("<QueryTaxpayerRequest>")).not_to be_empty
  end
end
