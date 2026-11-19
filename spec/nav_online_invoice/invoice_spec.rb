# frozen_string_literal: true

require "json"

RSpec.describe NavOnlineInvoice::Invoice do
  let(:invoice) do
    NavOnlineInvoice::InvoiceDataReader.new(Nokogiri::XML(fixture("invoices/foreign_currency.xml"))).invoices.first
  end
  let(:personal) do
    ["EXAMPLE TRADING", "BEISPIEL", "GYŐR", "MINTA", "HU00123456781234567812345678", "12345678-2-42", "1270",
     "508635", "400.5"]
  end

  it "leaves the parties and the amounts out of inspect and pp" do
    outputs = [invoice, invoice.supplier, invoice.customer, invoice.summary, invoice.summary.by_vat_rate.first]
              .flat_map { |record| [record.inspect, PP.pp(record, +""), record.to_s] }

    outputs.each { |output| expect(output).not_to include(*personal) }
    expect(invoice.inspect).to include("INV-2026-0002", "EUR", "modification=false")
  end

  it "turns nested records into hashes in to_h" do
    hash = invoice.to_h

    expect(hash.dig(:supplier, :address, :city)).to eq("GYŐR")
    expect(hash.dig(:summary, :by_vat_rate, 0, :vat_rate)).to eq(kind: :percentage, rate: 0.27r, code: nil,
                                                                 reason: nil)
    expect(hash[:exchange_rate]).to eq(BigDecimal("400.5"))
  end

  it "can be written as JSON" do
    json = JSON.parse(JSON.generate(invoice.to_h))

    expect(json.dig("supplier", "bank_account_number")).to eq("HU00123456781234567812345678")
    expect(json.dig("customer", "vat_status")).to eq("other")
  end

  it "keeps the block form of to_h" do
    expect(invoice.to_h { |key, value| [key.to_s, value] }.keys.first).to eq("invoice_number")
  end
end
