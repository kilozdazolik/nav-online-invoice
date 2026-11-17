# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Invoices do
  let(:base) { "https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3" }
  let(:invoices) { NavOnlineInvoice::Client.new(build_config).invoices }

  it "checks an invoice number" do
    stub_request(:post, "#{base}/queryInvoiceCheck").to_return(body: fixture("responses/query_invoice_check/true.xml"))

    expect(invoices.check("INV-2026-0001", direction: :outbound)).to be(true)
  end

  it "reports an invalid invoice number as false" do
    stub_request(:post, "#{base}/queryInvoiceCheck").to_return(body: fixture("responses/query_invoice_check/false.xml"))

    expect(invoices.check("INV-2026-0001", direction: :outbound)).to be(false)
  end

  it "fetches an invoice" do
    stub_request(:post, "#{base}/queryInvoiceData")
      .to_return(body: fixture("responses/query_invoice_data/found_compressed.xml"))

    expect(invoices.data("INV-2026-0001", direction: :outbound).invoice_xml).to include("INV-2026-0001")
  end

  it "walks an invoice chain" do
    stub_request(:post, "#{base}/queryInvoiceChainDigest")
      .to_return(body: fixture("responses/query_invoice_chain_digest/chain.xml"))

    expect(invoices.each_chain_element("INV-2026-0000", direction: :outbound).map(&:operation)).to eq(%i[create modify])
  end

  describe "#each_digest" do
    let(:endpoint) { "#{base}/queryInvoiceDigest" }
    let(:november) { Date.new(2026, 11, 1)..Date.new(2026, 11, 30) }

    def page_answer(page)
      fixture("responses/query_invoice_digest/page.xml").sub("<currentPage>1<", "<currentPage>#{page}<")
    end

    it "walks the pages lazily and stops at max_pages" do
      stub_request(:post, endpoint).with(body: /<page>1</).to_return(body: page_answer(1))
      stub_request(:post, endpoint).with(body: /<page>2</).to_return(body: page_answer(2))

      expect(invoices.each_digest(direction: :outbound, issue_date: november).to_a.size).to eq(4)
      expect(invoices.each_digest(direction: :outbound, issue_date: november, max_pages: 1).to_a.size).to eq(2)
    end

    it "rejects bad filters before any request" do
      expect { invoices.each_digest(direction: :outbound) }.to raise_error(ArgumentError, /exactly one/)
      expect(a_request(:post, endpoint)).not_to have_been_made
    end
  end
end
