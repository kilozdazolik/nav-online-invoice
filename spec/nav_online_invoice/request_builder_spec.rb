# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::RequestBuilder do
  let(:operation) do
    Struct.new(:request_root) do
      def build_body(xml) = xml.taxNumber("22222222")
    end.new("QueryTaxpayerRequest")
  end

  it "reproduces NAV's official sample request exactly" do
    xml = described_class.new(official_sample_config)
                         .build(operation, request_id: "RID215118906689", time: Time.utc(2019, 9, 11, 11, 11, 8.579r))

    expect(canonical(xml)).to eq(canonical(fixture("requests/query_taxpayer_official.xml")))
  end

  it "builds a request that matches the NAV schema" do
    xml = described_class.new(build_config).build(operation, request_id: "NOI1", time: Time.now)

    expect(xml).to be_valid_nav_xml
  end

  it "leaves out the optional software fields that are not set" do
    xml = described_class.new(build_config).build(operation, request_id: "NOI1", time: Time.now)

    expect(xml).not_to include("softwareDevCountryCode", "softwareDevTaxNumber")
  end

  it "escapes special characters" do
    config = build_config(software: ConfigHelpers::SOFTWARE.merge(name: "Kovács & Társa <Kft>"))
    xml = described_class.new(config).build(operation, request_id: "NOI1", time: Time.now)

    expect(xml).to include("Kovács &amp; Társa &lt;Kft&gt;")
    expect(xml).to be_valid_nav_xml
  end
end
