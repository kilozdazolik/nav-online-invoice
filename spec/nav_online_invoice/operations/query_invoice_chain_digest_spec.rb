# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryInvoiceChainDigest do
  def parse
    xml = fixture("responses/query_invoice_chain_digest/chain.xml")
    described_class.new("INV-2026-0000", direction: :outbound)
                   .parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)
  end

  it "builds the body of NAV's official sample" do
    operation = described_class.new("2019/1234", direction: :outbound, tax_number: "22222222")

    expect(request_body(build_request(operation)))
      .to eq(request_body(fixture("requests/query_invoice_chain_digest_official.xml")))
  end

  it "builds a request that matches the schema" do
    expect(build_request(described_class.new("INV-2026-0000", direction: :inbound, page: 2))).to be_valid_nav_xml
  end

  it "rejects invalid parameters" do
    expect { described_class.new("X", direction: :outbound, tax_number: "1") }.to raise_error(ArgumentError, /tax/)
  end

  it "reads the original invoice and its modification" do
    original, modification = parse.items

    expect(original).to have_attributes(invoice_number: "INV-2026-0000", operation: :create, reference: nil,
                                        new_created_lines: [], max_line_number: nil)
    expect(modification).to have_attributes(operation: :modify, batch_index: 1, max_line_number: 5,
                                            new_created_lines: [3..4, 5..5],
                                            ins_date: Time.utc(2026, 11, 16, 8, 15, 30.12r))
    expect(modification.reference).to have_attributes(original_invoice_number: "INV-2026-0000",
                                                      modify_without_master: false, modification_index: 1,
                                                      modification_timestamp: nil)
  end

  it "keeps tax numbers out of inspect" do
    expect(parse.items.first.inspect).not_to include("12345678", "87654321")
  end
end
