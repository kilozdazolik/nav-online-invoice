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
end
