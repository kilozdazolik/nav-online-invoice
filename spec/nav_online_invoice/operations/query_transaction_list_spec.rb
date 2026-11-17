# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryTransactionList do
  let(:range) { Time.utc(2020, 2, 5, 6, 46, 42.223r)..Time.utc(2020, 2, 5, 8, 53, 16.165r) }

  it "builds the body of NAV's official sample" do
    expect(request_body(build_request(described_class.new(ins_date: range))))
      .to eq(request_body(fixture("requests/query_transaction_list_official.xml")))
  end

  it "builds a request that matches the schema, with a status filter" do
    xml = build_request(described_class.new(ins_date: range, status: :finished, page: 2))

    expect(xml).to be_valid_nav_xml
    expect(xml).to include("<requestStatus>FINISHED</requestStatus>", "<page>2</page>")
  end

  it "rejects invalid parameters" do
    expect { described_class.new(ins_date: range, status: :lost) }.to raise_error(ArgumentError, /status/)
    expect { described_class.new(ins_date: range.end..range.begin) }.to raise_error(ArgumentError, /after/)
  end

  it "reads a page of transactions" do
    xml = fixture("responses/query_transaction_list/page.xml")
    page = described_class.new(ins_date: range).parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)

    expect(page).to have_attributes(current_page: 1, total_pages: 2, size: 2, last_page?: false)
    expect(page.items.first).to have_attributes(
      transaction_id: "3XAMPLETRANSACT10N01", ins_date: Time.utc(2026, 11, 16, 8, 15, 30.12r), source: :xml,
      status: :finished, technical_annulment: false, original_request_version: "3.0", item_count: 2
    )
    expect(page.items.first.inspect).not_to include("specuser")
  end

  it "reads an empty result" do
    xml = fixture("responses/query_transaction_list/empty.xml")
    page = described_class.new(ins_date: range).parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)

    expect(page).to have_attributes(total_pages: 0, empty?: true, last_page?: true)
  end

  it "is not rate limited and may be retried" do
    expect([described_class.new(ins_date: range).rate_limited?, described_class.new(ins_date: range).auto_retry?])
      .to eq([false, true])
  end
end
