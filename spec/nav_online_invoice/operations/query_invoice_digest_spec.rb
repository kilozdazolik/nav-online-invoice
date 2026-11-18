# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryInvoiceDigest do
  let(:november) { Date.new(2026, 11, 1)..Date.new(2026, 11, 30) }

  def parse(path)
    xml = fixture("responses/query_invoice_digest/#{path}")
    described_class.new(direction: :outbound, issue_date: november)
                   .parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)
  end

  def without_relational(xml)
    document = Nokogiri::XML(xml)
    document.xpath("//api:relationalQueryParams", NavOnlineInvoice::NAMESPACES).remove
    document.to_xml
  end

  it "builds the body of NAV's sample for an original invoice number" do
    operation = described_class.new(direction: :inbound,
                                    original_invoice_number: "05921263386905374149059212633869053741490592126355")

    expect(request_body(build_request(operation)))
      .to eq(request_body(fixture("requests/query_invoice_digest_inbound_invoice_chain_official.xml")))
  end

  it "builds the body of NAV's sample with additional and transaction filters" do
    operation = described_class.new(
      direction: :outbound, issue_date: Date.new(2019, 1, 1)..Date.new(2019, 1, 28),
      tax_number: "22222222", group_member_tax_number: "33333333", name: "string", category: :aggregate,
      payment_method: :cash, appearance: :electronic, source: :mgm, currency: "WJP",
      transaction_id: "string", index: 1, operation: :storno
    )
    sample = fixture("requests/query_invoice_digest_outbound_query_params_official.xml")

    expect(request_body(build_request(operation))).to eq(request_body(without_relational(sample)))
  end

  it "builds relational conditions as single values and closed ranges" do
    xml = build_request(described_class.new(direction: :outbound, issue_date: november,
                                            delivery_date: Date.new(2019, 9, 9),
                                            net_amount: 1000..5000, vat_amount_huf: 1_234_567_890_123_456.12r))

    conditions = Nokogiri::XML(xml).xpath("//api:relationalQueryParams/*", NavOnlineInvoice::NAMESPACES)
                         .map { |node| [node.name, *node.element_children.map(&:text)].join(" ") }

    expect(xml).to be_valid_nav_xml
    expect(conditions).to eq(["invoiceDelivery EQ 2019-09-09", "invoiceNetAmount GTE 1000.00",
                              "invoiceNetAmount LTE 5000.00", "invoiceVatAmountHUF EQ 1234567890123456.12"])
  end

  it "builds an insertion time query that matches the schema" do
    xml = build_request(described_class.new(direction: :inbound,
                                            ins_date: Time.utc(2026, 11,
                                                               1)..Time.utc(2026, 11, 2)))

    expect(xml).to be_valid_nav_xml
    expect(xml).to include("<dateTimeFrom>2026-11-01T00:00:00.000Z</dateTimeFrom>")
  end

  {
    "no mandatory filter" => [{}, /exactly one/],
    "two mandatory filters" => [{ original_invoice_number: "X", ins_date: Time.now..Time.now }, /exactly one/],
    "an unknown filter" => [{ original_invoice_number: "X", color: :red }, /unknown filter: color/],
    "a short name" => [{ original_invoice_number: "X", name: "ABC" }, /name/],
    "an open amount range" => [{ original_invoice_number: "X", net_amount: 1000.. }, /both/],
    "an index without transaction" => [{ original_invoice_number: "X", index: 1 }, /needs transaction_id/],
    "a bad currency" => [{ original_invoice_number: "X", currency: "EURO" }, /currency/],
    "a long date range" => [{ issue_date: Date.new(2026, 1, 1)..Date.new(2026, 3, 1) }, /35 days/]
  }.each do |description, (filters, message)|
    it "rejects #{description}" do
      expect { described_class.new(direction: :outbound, **filters) }.to raise_error(ArgumentError, message)
    end
  end

  it "reads a page of invoices with all fields" do
    page = parse("page.xml")
    invoice = page.items.first

    expect(page).to have_attributes(current_page: 1, total_pages: 2, size: 2)
    expect(invoice).to have_attributes(
      invoice_number: "INV-2026-0001", batch_index: 1, operation: :modify, category: :normal,
      issue_date: Date.new(2026, 11, 16), supplier_name: "EXAMPLE TRADING KFT.", customer_tax_number: "87654321",
      payment_method: :transfer, appearance: :electronic, source: :xml, currency: "HUF",
      net_amount: BigDecimal("20000"), vat_amount_huf: BigDecimal("5400"), original_invoice_number: "INV-2026-0000",
      modification_index: 2, ins_date: Time.utc(2026, 11, 16, 8, 15, 30.12r), completeness_indicator: false,
      complete?: false
    )
    expect(invoice.net_amount).to be_a(BigDecimal)
  end

  it "reads an invoice with only the required fields" do
    expect(parse("page.xml").items.last).to have_attributes(customer_name: nil, net_amount: nil, category: :simplified)
  end

  it "reads an empty result" do
    expect(parse("empty.xml")).to have_attributes(empty?: true, total_pages: 0)
  end

  it "keeps names and amounts out of inspect" do
    shown = parse("page.xml").items.first

    expect([shown.inspect, shown.pretty_inspect].join).not_to include("EXAMPLE", "PÉLDA", "20000", "87654321")
  end
end
