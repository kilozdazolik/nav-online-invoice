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

  it "validates invoices against the data schema" do
    expect(described_class.errors(official_request, schema: :data).join).to include("QueryTaxpayerRequest")
  end

  it "rejects an unknown schema" do
    expect { described_class.errors(official_request, schema: :other) }.to raise_error(ArgumentError, /schema/)
  end

  it "reports malformed XML" do
    expect(described_class.errors("<QueryTaxpayerRequest>")).not_to be_empty
  end

  describe "request and response fixtures" do
    Dir[File.join(FixtureHelpers::FIXTURE_DIR, "{requests,responses}/**/*.xml")].each do |path|
      name = path.delete_prefix("#{FixtureHelpers::FIXTURE_DIR}/")

      it "accepts #{name}" do
        expect(File.read(path)).to be_valid_nav_xml
      end
    end
  end
end
