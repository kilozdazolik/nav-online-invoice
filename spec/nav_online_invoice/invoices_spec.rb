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
end
