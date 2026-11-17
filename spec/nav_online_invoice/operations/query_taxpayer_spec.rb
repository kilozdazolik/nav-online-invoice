# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryTaxpayer do
  def parse(path)
    xml = fixture("responses/query_taxpayer/#{path}")
    described_class.new("12345678").parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)
  end

  it "reads a valid taxpayer with addresses" do
    result = parse("valid.xml")
    taxpayer = result.taxpayer

    expect(result).to have_attributes(valid?: true, request_id: "RID1", info_date: Time.utc(2024, 5, 1))
    expect(taxpayer).to have_attributes(name: "EXAMPLE TRADING KORLÁTOLT FELELŐSSÉGŰ TÁRSASÁG",
                                        tax_number: "12345678-2-42", incorporation: :organization)
    expect(taxpayer.addresses.map(&:type)).to eq(%i[hq site])
    expect(taxpayer.headquarters).to have_attributes(postal_code: "1234", city: "BUDAPEST", street_name: "MINTA",
                                                     public_place_category: "UTCA", number: "12", door: nil)
  end

  it "reads all address parts" do
    site = parse("valid.xml").taxpayer.addresses.last

    expect(site).to have_attributes(region: "PEST", public_place_category: "ÚT", building: "B", staircase: "2",
                                    floor: "1", door: "4", lot_number: nil)
  end

  it "reads a taxpayer with only the required data" do
    result = parse("valid_minimal.xml")

    expect(result.valid?).to be(true)
    expect(result.taxpayer).to have_attributes(tax_number: "87654321", vat_code: nil, incorporation: :self_employed,
                                               addresses: [], headquarters: nil)
  end

  it "reports an unknown tax number without an error" do
    result = parse("invalid.xml")

    expect(result).to have_attributes(valid?: false, validity: false, taxpayer: nil)
  end

  it "keeps a missing validity as nil" do
    result = parse("validity_missing.xml")

    expect(result).to have_attributes(valid?: false, validity: nil, info_date: nil)
  end

  it "does not show the raw XML in inspect or pp" do
    result = parse("valid.xml")

    expect(result.inspect).not_to include("<?xml")
    expect(result.pretty_inspect).not_to include("<?xml")
  end

  it "checks a full tax number against NAV's data" do
    result = parse("valid.xml")

    expect(result.matches?("12345678-2-42")).to be(true)
    expect(result.matches?("12345678")).to be(true)
    expect(result.matches?("12345678-1-42")).to be(false)
    expect(parse("invalid.xml").matches?("12345678")).to be(false)
  end

  it "sends the 8-digit tax number" do
    xml = Nokogiri::XML::Builder.new { |builder| described_class.new("87654321-1-13").build_body(builder) }.to_xml

    expect(xml).to include("<taxNumber>87654321</taxNumber>")
  end

  it "rejects a malformed tax number" do
    expect { described_class.new("1234") }.to raise_error(ArgumentError)
  end
end
