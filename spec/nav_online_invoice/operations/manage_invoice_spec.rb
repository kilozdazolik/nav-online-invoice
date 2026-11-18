# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::ManageInvoice do
  let(:token) do
    NavOnlineInvoice::ExchangeToken.new(value: "SPEC-TOKEN", valid_from: Time.utc(2026, 11, 18, 9),
                                        valid_to: Time.utc(2026, 11, 18, 9, 5), received_at: 1000.0)
  end
  let(:invoice) { NavOnlineInvoice::Payload.encode(fixture("invoices/invoice_data.xml"), compressed: false) }

  def item(operation = "CREATE", data = invoice, electronic_invoice_hash = nil)
    described_class::Item.new(operation:, data:, electronic_invoice_hash:)
  end

  it "reproduces NAV's official sample request exactly" do
    sample = Nokogiri::XML(fixture("requests/manage_invoice_official.xml"))
    items = sample.xpath("//api:invoiceOperation[api:index]", NavOnlineInvoice::NAMESPACES).map do |node|
      hash = node.at_xpath("api:electronicInvoiceHash", NavOnlineInvoice::NAMESPACES)
      item(node.at_xpath("api:invoiceOperation", NavOnlineInvoice::NAMESPACES).text,
           node.at_xpath("api:invoiceData", NavOnlineInvoice::NAMESPACES).text,
           { value: hash.text, crypto_type: hash["cryptoType"] })
    end
    operation = described_class.new(token: token.with(value: "b1aca173-d9e8-4561-9237-0511eed99eaa2P0ZHLXBRI2U"),
                                    items:, compressed: false)

    xml = NavOnlineInvoice::RequestBuilder.new(official_sample_config)
                                          .build(operation, request_id: "RID181837288942",
                                                            time: Time.utc(2020, 9, 11, 12, 44, 55.442r))

    expect(canonical(xml)).to eq(canonical(fixture("requests/manage_invoice_official.xml")))
  end

  it "builds a request that matches the schema" do
    operation = described_class.new(token:, items: [item, item("MODIFY")], compressed: false)

    expect(build_request(operation)).to be_valid_nav_xml
  end

  it "signs every invoice in index order" do
    operation = described_class.new(token:, items: [item, item("STORNO", "QUJD")], compressed: false)

    expect(operation.index_hashes).to eq([NavOnlineInvoice::Crypto.index_hash("CREATE", invoice),
                                          NavOnlineInvoice::Crypto.index_hash("STORNO", "QUJD")])
  end

  it "writes the compression flag once for the whole request" do
    data = NavOnlineInvoice::Payload.encode(fixture("invoices/invoice_data.xml"), compressed: true)
    xml = build_request(described_class.new(token:, items: [item("CREATE", data)], compressed: true))

    expect(xml).to include("<compressedContent>true</compressedContent>")
    expect(xml).to be_valid_nav_xml
  end

  it "takes 1 to 100 invoices" do
    expect { described_class.new(token:, items: [], compressed: false) }.to raise_error(ArgumentError, /1-100/)
    expect { described_class.new(token:, items: [item] * 101, compressed: false) }.to raise_error(ArgumentError)
  end

  it "stops before sending once the token is about to expire" do
    operation = described_class.new(token:, items: [item], compressed: false)
    allow(NavOnlineInvoice::ExchangeToken).to receive(:now).and_return(1000.0 + 280)

    expect { operation.check_before_send! }.to raise_error(NavOnlineInvoice::ExchangeTokenError, /expired/)
  end

  it "reads the transaction ID" do
    xml = fixture("responses/manage_invoice/ok.xml")
    items = [item, item("MODIFY", "QUJD", { value: "AB", crypto_type: "SHA-256" })]
    operation = described_class.new(token:, items:, compressed: false)

    expect(xml).to be_valid_nav_xml
    expect(operation.parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)).to eq(
      NavOnlineInvoice::Submission.new(transaction_id: "4Q8O2ZCTX1J8WGZ2", request_id: "RID1", item_count: 2,
                                       compressed: false, electronic_invoice_hashes: [nil, "AB"])
    )
  end

  it "is a rate limited submission that is never retried" do
    operation = described_class.new(token:, items: [item], compressed: false)

    expect(operation).to have_attributes(submission?: true, rate_limited?: true, auto_retry?: false,
                                         max_body_bytes: 10_000_000)
  end

  it "does not show the token or the invoices" do
    operation = described_class.new(token:, items: [item], compressed: false)

    expect(operation.inspect).not_to include("SPEC-TOKEN", invoice[0, 20])
    expect(item.inspect).not_to include(invoice[0, 20])
  end
end
