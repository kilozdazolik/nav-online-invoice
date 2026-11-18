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

  describe "#submit" do
    let(:throttle) { instance_spy(NavOnlineInvoice::Throttle) }
    let(:invoices) { NavOnlineInvoice::Client.new(build_config(throttle:)).invoices }
    let(:items) { [{ operation: :create, xml: fixture("invoices/invoice_data.xml") }] }
    let(:token_answer) { { body: fixture("responses/token_exchange/ok.xml") } }

    before do
      stub_request(:post, "#{base}/tokenExchange").to_return(token_answer)
    end

    def stub_submission(answer = { body: fixture("responses/manage_invoice/ok.xml") })
      stub_request(:post, "#{base}/manageInvoice").to_return(answer)
    end

    it "requests a token and submits the invoices with it" do
      stub_submission

      submission = invoices.submit(items)

      expect(submission).to have_attributes(transaction_id: "4Q8O2ZCTX1J8WGZ2", item_count: 1, compressed: false)
      expect(a_request(:post, "#{base}/manageInvoice").with do |request|
        body = Nokogiri::XML(request.body)
        data = body.at_xpath("//api:invoiceData", NavOnlineInvoice::NAMESPACES).text
        body.at_xpath("//api:exchangeToken", NavOnlineInvoice::NAMESPACES).text == "SPEC-TOKEN-0123456789-ABCDEF" &&
          NavOnlineInvoice::Payload.decode(data, compressed: false) == items.first[:xml]
      end).to have_been_made.once
      expect(throttle).to have_received(:wait).with("tokenExchange").ordered
      expect(throttle).to have_received(:wait).with("manageInvoice").ordered
    end

    it "sends nothing without an exchange key" do
      invoices = NavOnlineInvoice::Client.new(build_config(exchange_key: nil)).invoices

      expect { invoices.submit(items) }.to raise_error(NavOnlineInvoice::ConfigurationError, /exchange_key/)
      expect(a_request(:post, /onlineszamla/)).not_to have_been_made
    end

    it "sends nothing, not even a token request, for an invalid invoice" do
      expect { invoices.submit([{ operation: :create, xml: "<InvoiceData/>" }]) }
        .to raise_error(NavOnlineInvoice::SchemaValidationError)
      expect(a_request(:post, /onlineszamla/)).not_to have_been_made
    end

    it "replaces a token that expired while waiting, and still submits once" do
      stub_submission
      clock = 0.0
      allow(NavOnlineInvoice::Monotonic).to receive(:now) { clock }
      waits = 0
      allow(throttle).to receive(:wait) { |name| clock += 280 if name == "manageInvoice" && (waits += 1) == 1 }

      expect(invoices.submit(items).transaction_id).to eq("4Q8O2ZCTX1J8WGZ2")
      expect(a_request(:post, "#{base}/tokenExchange")).to have_been_made.twice
      expect(a_request(:post, "#{base}/manageInvoice")).to have_been_made.once
    end

    it "does not resubmit when NAV rejects the token" do
      stub_submission(status: 400, body: fixture("responses/general_error/invalid_exchange_token.xml"))

      expect { invoices.submit(items) }.to raise_error(NavOnlineInvoice::ExchangeTokenError, &:retryable?)
      expect(a_request(:post, "#{base}/manageInvoice")).to have_been_made.once
    end

    it "raises UnknownOutcomeError when the submission gets no answer" do
      stub_request(:post, "#{base}/manageInvoice").to_timeout

      expect { invoices.submit(items) }.to raise_error(NavOnlineInvoice::UnknownOutcomeError)
      expect(a_request(:post, "#{base}/manageInvoice")).to have_been_made.once
    end

    it "dates the lost submission by NAV's clock, worked out from the token" do
      stub_request(:post, "#{base}/manageInvoice").to_timeout
      clock = 1000.0
      allow(NavOnlineInvoice::Monotonic).to receive(:now) { clock }
      allow(throttle).to receive(:wait) { |name| clock += 42 if name == "manageInvoice" }

      expect { invoices.submit(items) }.to raise_error(NavOnlineInvoice::UnknownOutcomeError) { |error|
        # the token is valid from 10:00:00 by NAV's clock, and the request waited 42 seconds for the throttle
        expect(error.sent_at).to eq(Time.utc(2026, 11, 17, 10, 0, 42))
      }
    end

    it "retries a failed token request, which changes nothing" do
      stub_submission
      stub_request(:post, "#{base}/tokenExchange").to_timeout.then.to_return(token_answer)
      invoices = NavOnlineInvoice::Client.new(build_config(retry_base_delay: 0)).invoices

      expect(invoices.submit(items).transaction_id).to eq("4Q8O2ZCTX1J8WGZ2")
    end
  end

  describe "#annul" do
    let(:items) { [{ reference: "INV-2026-0001", code: :erratic_invoice_number, reason: "Wrong number" }] }

    it "requests a token and submits the annulments with it" do
      stub_request(:post, "#{base}/tokenExchange").to_return(body: fixture("responses/token_exchange/ok.xml"))
      stub_request(:post, "#{base}/manageAnnulment").to_return(
        body: fixture("responses/manage_invoice/ok.xml").gsub("ManageInvoiceResponse", "ManageAnnulmentResponse")
      )

      expect(invoices.annul(items).transaction_id).to eq("4Q8O2ZCTX1J8WGZ2")
      expect(a_request(:post, "#{base}/manageAnnulment").with do |request|
        data = Nokogiri::XML(request.body).at_xpath("//api:invoiceAnnulment", NavOnlineInvoice::NAMESPACES).text
        NavOnlineInvoice::Payload.decode(data, compressed: false).include?("ERRATIC_INVOICE_NUMBER")
      end).to have_been_made.once
    end

    it "sends nothing for an invalid annulment" do
      expect { invoices.annul([items.first.merge(code: :typo)]) }.to raise_error(ArgumentError)
      expect(a_request(:post, /onlineszamla/)).not_to have_been_made
    end
  end
end
