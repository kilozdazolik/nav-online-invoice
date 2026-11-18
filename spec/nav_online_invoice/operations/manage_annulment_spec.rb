# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::ManageAnnulment do
  let(:token) do
    NavOnlineInvoice::ExchangeToken.new(value: "SPEC-TOKEN", valid_from: Time.utc(2026, 11, 18, 9),
                                        valid_to: Time.utc(2026, 11, 18, 9, 5), received_at: 1000.0)
  end
  let(:sample) { Nokogiri::XML(fixture("requests/manage_annulment_official.xml")) }
  let(:sample_data) { sample.at_xpath("//api:invoiceAnnulment", NavOnlineInvoice::NAMESPACES).text }

  def item(data = sample_data)
    NavOnlineInvoice::Operations::Manage::Item.new(operation: "ANNUL", data:)
  end

  it "reproduces NAV's official sample request exactly" do
    operation = described_class.new(token: token.with(value: "dbd03076-3a9b-4312-bbbb-0cee3a6472572P11CS49ASIL"),
                                    items: [item])

    xml = NavOnlineInvoice::RequestBuilder.new(official_sample_config)
                                          .build(operation, request_id: "RID338592103413",
                                                            time: Time.utc(2019, 9, 11, 13, 37, 9.385r))

    expect(canonical(xml)).to eq(canonical(fixture("requests/manage_annulment_official.xml")))
  end

  it "builds a request that matches the schema" do
    expect(build_request(described_class.new(token:, items: [item, item]))).to be_valid_nav_xml
  end

  it "is a rate limited submission that is never retried" do
    expect(described_class.new(token:, items: [item]))
      .to have_attributes(submission?: true, rate_limited?: true, auto_retry?: false)
  end

  it "reads the transaction ID" do
    xml = fixture("responses/manage_invoice/ok.xml").gsub("ManageInvoiceResponse", "ManageAnnulmentResponse")
    submission = described_class.new(token:, items: [item]).parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)

    expect(submission).to have_attributes(transaction_id: "4Q8O2ZCTX1J8WGZ2", item_count: 1, compressed: false)
  end
end
