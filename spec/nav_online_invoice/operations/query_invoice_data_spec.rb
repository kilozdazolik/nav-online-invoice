# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryInvoiceData do
  def parse(path)
    xml = fixture("responses/query_invoice_data/#{path}")
    described_class.new("INV-2026-0001", direction: :outbound).parse(Nokogiri::XML(xml), request_id: "RID1",
                                                                                         raw_xml: xml)
  end

  %w[found.xml found_compressed.xml].each do |path|
    it "decodes the invoice in #{path}" do
      result = parse(path)

      expect(result.invoice_xml).to eq(fixture("invoices/invoice_data.xml"))
      expect(result.document.root.name).to eq("InvoiceData")
      expect(result.compressed).to eq(path.include?("compressed"))
    end
  end

  it "reads the audit data and the hash" do
    result = parse("found.xml")

    expect(result.audit_data).to have_attributes(ins_date: Time.utc(2026, 11, 16, 8, 15, 30.12r), source: :xml,
                                                 transaction_id: "3XAMPLETRANSACT10N01", index: 1,
                                                 original_request_version: "3.0")
    expect(result.electronic_invoice_hash)
      .to have_attributes(crypto_type: "SHA3-512", value: a_string_matching(/\A\h{128}\z/))
  end

  it "returns nil when NAV has no such invoice" do
    expect(parse("not_found.xml")).to be_nil
  end

  it "raises DecodeError for broken invoice data" do
    xml = fixture("responses/query_invoice_data/found_compressed.xml").sub(/<invoiceData>\w{8}/, "<invoiceData>")

    expect { described_class.new("X", direction: :outbound).parse(Nokogiri::XML(xml), request_id: "R", raw_xml: xml) }
      .to raise_error(NavOnlineInvoice::DecodeError)
  end

  it "keeps the invoice and the login out of inspect" do
    result = parse("found.xml")

    expect([result.inspect, result.pretty_inspect].join).not_to include("EXAMPLE TRADING", "specuser", "PFhNT")
  end

  it "is rate limited and may be retried" do
    operation = described_class.new("X", direction: :outbound)

    expect([operation.rate_limited?, operation.auto_retry?]).to eq([true, true])
  end
end
