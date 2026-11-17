# frozen_string_literal: true

# Calls NAV for real, see query_taxpayer_spec.rb. Real invoices hold personal data, so these specs check only
# counts and types and never put an invoice into a failure message. In production they run only with
# NAV_ALLOW_PRODUCTION=1.
RSpec.describe "Invoice and transaction queries against NAV", :integration do # rubocop:disable RSpec/DescribeClass
  include_context "with NAV credentials"

  let(:now) { Time.now.utc }

  before do
    if environment == :production && env["NAV_ALLOW_PRODUCTION"] != "1"
      skip "Set NAV_ALLOW_PRODUCTION=1 to query real invoices in production"
    end
  end

  it "lists the transactions of the last day" do
    page = nav { client.transactions.list(ins_date: (now - 86_400)..now) }

    expect(page.total_pages).to be_a(Integer)
    expect(page.items.map(&:class).uniq - [NavOnlineInvoice::Transaction]).to be_empty
  end

  it "lists, checks and fetches outbound invoices of the last three days" do
    page = nav { client.invoices.digest(direction: :outbound, ins_date: (now - (3 * 86_400))..now) }
    expect(page.total_pages).to be_a(Integer)
    next if page.empty?

    number = page.items.first.invoice_number
    data = nav { client.invoices.data(number, direction: :outbound) }
    expect(nav { client.invoices.check(number, direction: :outbound) }).to be(true)
    expect(data.document.root.name).to eq("InvoiceData")
  end
end
