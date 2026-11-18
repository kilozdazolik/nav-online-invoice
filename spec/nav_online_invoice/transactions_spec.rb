# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Transactions do
  let(:endpoint) { "https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/queryTransactionList" }
  let(:transactions) { NavOnlineInvoice::Client.new(build_config(retry_base_delay: 0)).transactions }
  let(:range) { Time.utc(2026, 11, 16)..Time.utc(2026, 11, 17) }

  def page_answer(page, available)
    fixture("responses/query_transaction_list/page.xml")
      .sub("<currentPage>1</currentPage>", "<currentPage>#{page}</currentPage>")
      .sub("<availablePage>2</availablePage>", "<availablePage>#{available}</availablePage>")
  end

  it "lists one page" do
    stub_request(:post, endpoint).to_return(body: page_answer(1, 1))

    expect(transactions.list(ins_date: range).items.map(&:transaction_id))
      .to eq(%w[3XAMPLETRANSACT10N01 3XAMPLETRANSACT10N02])
  end

  it "walks all pages lazily" do
    stub_request(:post, endpoint).with(body: /<page>1</).to_return(body: page_answer(1, 2))
    stub_request(:post, endpoint).with(body: /<page>2</).to_return(body: page_answer(2, 2))

    expect(transactions.each_transaction(ins_date: range).first(1).size).to eq(1)
    expect(a_request(:post, endpoint)).to have_been_made.once
    expect(transactions.each_transaction(ins_date: range).to_a.size).to eq(4)
  end

  it "makes no second request for an empty result" do
    stub_request(:post, endpoint).to_return(body: fixture("responses/query_transaction_list/empty.xml"))

    expect(transactions.each_transaction(ins_date: range).to_a).to be_empty
    expect(a_request(:post, endpoint)).to have_been_made.once
  end

  describe "#wait" do
    let(:status_endpoint) { "https://api-test.onlineszamla.nav.gov.hu/invoiceService/v3/queryTransactionStatus" }
    let(:clock) { [0.0] }
    let(:pauses) { [] }

    before do
      allow(NavOnlineInvoice::Monotonic).to receive(:now) { clock.first }
      allow(transactions).to receive(:sleep) do |seconds|
        pauses << seconds
        clock[0] += seconds
      end
    end

    def answers(*names)
      stub_request(:post, status_endpoint)
        .to_return(*names.map { |name| { body: fixture("responses/query_transaction_status/#{name}.xml") } })
    end

    it "asks until NAV has finished with every item" do
      answers("processing", "processing", "aborted")

      status = transactions.wait("TRANSACTION1")

      expect(status).to have_attributes(finished?: true, accepted?: false)
      expect(a_request(:post, status_endpoint)).to have_been_made.times(3)
    end

    it "waits longer each time, up to 15 seconds" do
      answers("processing")

      transactions.wait("TRANSACTION1", timeout: 100)

      expect(pauses.first).to be_between(1.6, 2.4)
      expect(pauses.each_cons(2).count { |a, b| b > a }).to be >= 3
      expect(pauses.max).to be <= 18
    end

    it "returns the last status at the timeout" do
      answers("processing")

      expect(transactions.wait("TRANSACTION1", timeout: 10)).to have_attributes(finished?: false)
      expect(clock.first).to be_within(0.01).of(10)
    end

    it "keeps asking while NAV does not know the transaction yet" do
      answers("not_found", "aborted")

      expect(transactions.wait("TRANSACTION1")).to be_finished
    end

    it "returns nil if NAV never knew the transaction" do
      answers("not_found")

      expect(transactions.wait("TRANSACTION1", timeout: 5)).to be_nil
    end

    it "rejects a bad timeout or interval" do
      expect { transactions.wait("TRANSACTION1", timeout: -1) }.to raise_error(ArgumentError, /timeout/)
      expect { transactions.wait("TRANSACTION1", interval: 0) }.to raise_error(ArgumentError, /interval/)
    end
  end
end
