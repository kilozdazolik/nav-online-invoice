# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::InvoiceDataResult do
  let(:old_format) { '<InvoiceData xmlns="http://schemas.nav.gov.hu/OSA/2.0/data"><invoiceNumber>X</invoiceNumber></InvoiceData>' }

  def result(name, version: "3.0", xml: fixture("invoices/#{name}.xml"))
    audit = NavOnlineInvoice::AuditData.new(ins_date: nil, ins_cus_user: "specuser", source: :xml,
                                            transaction_id: "T1", index: 1, batch_index: nil,
                                            original_request_version: version)
    described_class.new(request_id: "RID1", invoice_xml: xml, compressed: false,
                        audit_data: audit, electronic_invoice_hash: nil, raw_xml: "")
  end

  it "reads the invoice" do
    expect(result("invoice_data").invoice).to have_attributes(invoice_number: "INV-2026-0001")
  end

  it "reads every invoice of a batch modification" do
    expect(result("batch").invoices.map(&:batch_index)).to eq([1, 2])
  end

  it "refuses to pick one invoice of a batch modification" do
    expect { result("batch").invoice }.to raise_error(ArgumentError, /2 invoices.*use #invoices/)
  end

  it "names the format of an older invoice" do
    expect { result(nil, version: "2.0", xml: old_format).invoice }
      .to raise_error(NavOnlineInvoice::UnsupportedInvoiceVersionError, /format 2\.0/)
  end
end
