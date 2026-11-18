# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::QueryTransactionStatus do
  def parse(path)
    xml = fixture("responses/query_transaction_status/#{path}")
    described_class.new("TRANSACTION1").parse(Nokogiri::XML(xml), request_id: "RID1", raw_xml: xml)
  end

  it "builds the body of NAV's official sample" do
    expect(request_body(build_request(described_class.new("string"))))
      .to eq(request_body(fixture("requests/query_transaction_status_official.xml")))
  end

  it "builds a request that matches the schema" do
    expect(build_request(described_class.new("TRANSACTION1", return_original_request: true))).to be_valid_nav_xml
  end

  it "rejects a malformed transaction ID" do
    expect { described_class.new("not valid") }.to raise_error(ArgumentError, /transaction_id/)
  end

  it "reads a submission in progress" do
    status = parse("processing.xml")

    expect(status.results)
      .to contain_exactly(have_attributes(index: 1, status: :processing, done?: false, pending?: true))
    expect(status).not_to be_finished
    expect(status).to have_attributes(original_request_version: "3.0", accepted?: false)
  end

  it "reads validation messages" do
    aborted, done = parse("aborted.xml").results

    expect(aborted).to have_attributes(aborted?: true, errors?: true)
    expect(aborted.technical_validation_messages.first).to have_attributes(result_code: :error)
    expect(aborted.business_validation_messages.first).to have_attributes(
      result_code: :error, error_code: "INVOICE_LINE_MISSING", tag: "invoiceLines", value: "0", line: 1,
      original_invoice_number: "INV-2026-0000"
    )
    expect(done).to have_attributes(done?: true, errors?: false, final?: true)
  end

  it "decodes the original request and reads annulment data" do
    status = parse("with_original_request.xml")

    expect(status.results.first.original_request).to eq(fixture("invoices/invoice_data.xml"))
    expect(status).to have_attributes(accepted?: true, annulled?: true, annulment_pending?: false,
                                      annulment_verification_status: :verification_done,
                                      annulment_decision_date: Time.utc(2026, 11, 17, 9, 30))
  end

  it "is not accepted while it has no results" do
    status = NavOnlineInvoice::TransactionStatus.new(
      request_id: "RID1", results: [], original_request_version: nil, annulment_verification_status: nil,
      annulment_decision_date: nil, annulment_decision_user: nil, raw_xml: ""
    )

    expect(status).to have_attributes(accepted?: false, finished?: false)
  end

  it "returns nil for an unknown transaction" do
    expect(parse("not_found.xml")).to be_nil
  end

  it "keeps invoices and logins out of inspect" do
    status = parse("with_original_request.xml")

    expect([status.inspect, status.pretty_inspect].join).not_to include("InvoiceData", "specuser")
  end
end
