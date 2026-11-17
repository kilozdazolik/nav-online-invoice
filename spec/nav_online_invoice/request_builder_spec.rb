# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::RequestBuilder do
  let(:operation) do
    Struct.new(:request_root) do
      def build_body(xml) = xml.taxNumber("22222222")
    end.new("QueryTaxpayerRequest")
  end

  # The values of NAV's official sample request.
  let(:sample_config) do
    NavOnlineInvoice::Configuration.new(
      environment: :test,
      login: "lwilsmn0uqdxe6u",
      password_hash: "2F43840A882CFDB7DB0FEC07D419D030D864B47B6B541DC280EF81B937B7A176" \
                     "E33C052B0D26638CC18A7A2C08D8D311733078A774BF43F6CA57FE8CD74DC28E",
      signature_key: "ac-ac3a-7f661bff7d342N43CYX4U9FG",
      tax_number: "11111111",
      software: {
        id: "123456789123456789", name: "string", operation: :local_software, main_version: "string",
        dev_name: "string", dev_contact: "string", dev_country_code: "HU", dev_tax_number: "string"
      }
    )
  end

  def canonical(xml)
    document = Nokogiri::XML(xml, &:noblanks)
    document.xpath("//comment()").remove
    document.canonicalize
  end

  it "reproduces NAV's official sample request exactly" do
    xml = described_class.new(sample_config)
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
