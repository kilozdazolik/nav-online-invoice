# frozen_string_literal: true

# Submits an invented invoice to NAV's test environment, waits for it, and with NAV_ALLOW_ANNULMENT=1 also
# annuls it (the annulment then waits for approval on NAV's web interface). Never runs against production.
#
#   NAV_ALLOW_SUBMISSION=1 NAV_EXCHANGE_KEY=... in .env, then
#   bin/dev sh -c 'NAV_INTEGRATION=1 bundle exec rspec spec/integration/submission_spec.rb'
RSpec.describe "Invoice submission against NAV's test environment", :integration do # rubocop:disable RSpec/DescribeClass
  include_context "with NAV credentials"

  let(:today) { Time.now.utc.to_date }
  let(:invoice_number) { "SPEC-#{Time.now.utc.strftime("%Y%m%d%H%M%S")}-#{SecureRandom.hex(3).upcase}" }

  # The invented spec invoice, issued today by the technical user's company to a private person.
  let(:invoice_xml) do
    supplier = "<base:taxpayerId>#{env.fetch("NAV_TAX_NUMBER")[0, 8]}</base:taxpayerId>"
    customer = "<customerInfo><customerVatStatus>PRIVATE_PERSON</customerVatStatus></customerInfo>"
    fixture("invoices/invoice_data.xml")
      .sub(%r{<invoiceNumber>.*?</invoiceNumber>}, "<invoiceNumber>#{invoice_number}</invoiceNumber>")
      .gsub("2026-11-16", today.iso8601).sub("2026-11-24", (today + 8).iso8601)
      .sub(%r{<base:taxpayerId>12345678</base:taxpayerId>.*?</base:countyCode>}m, supplier)
      .sub(%r{<customerInfo>.*</customerInfo>}m, customer)
  end

  before do
    unless environment == :test && client.config.endpoint("manageInvoice").host == "api-test.onlineszamla.nav.gov.hu"
      skip "Submission specs run only against NAV's test environment"
    end
    skip "Set NAV_ALLOW_SUBMISSION=1 to submit an invented invoice" unless env["NAV_ALLOW_SUBMISSION"] == "1"
    skip "Set NAV_EXCHANGE_KEY to submit" unless client.config.exchange_key
  end

  # Only codes go into the output, never the invoice.
  def codes(status)
    status.results.flat_map { |result| result.technical_validation_messages + result.business_validation_messages }
          .map(&:error_code).compact.uniq.join(", ")
  end

  it "submits an invoice and follows it until NAV has processed it" do
    submission = nav { client.invoices.submit([{ operation: :create, xml: invoice_xml }]) }
    status = client.transactions.wait(submission.transaction_id, timeout: 120)

    expect(status&.finished?).to be(true)
    expect(status.results.all?(&:done?)).to be(true), "NAV aborted the invoice: #{codes(status)}"
    next unless env["NAV_ALLOW_ANNULMENT"] == "1"

    annulment = client.invoices.annul([{ reference: invoice_number, code: :erratic_data,
                                         reason: "Invented invoice of the gem's integration spec" }])
    status = client.transactions.wait(annulment.transaction_id, timeout: 120)
    expect(status&.annulment_pending?).to be(true), "annulment not pending: #{codes(status)}"
  end
end
