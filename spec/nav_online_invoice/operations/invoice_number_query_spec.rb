# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Operations::InvoiceNumberQuery do
  {
    NavOnlineInvoice::Operations::QueryInvoiceCheck => "query_invoice_check_official.xml",
    NavOnlineInvoice::Operations::QueryInvoiceData => "query_invoice_data_official.xml"
  }.each do |operation, sample|
    describe operation do
      # NAV's samples send supplierTaxNumber with OUTBOUND, which NAV itself rejects.
      it "rejects the parameters of NAV's sample, which NAV would refuse" do
        expect { operation.new("string", direction: :outbound, batch_index: 3, supplier_tax_number: "22222222") }
          .to raise_error(ArgumentError, /supplier_tax_number/)
      end

      it "builds the body of NAV's sample for an inbound invoice" do
        expected = fixture("requests/#{sample}").sub("OUTBOUND", "INBOUND")
        built = operation.new("string", direction: :inbound, batch_index: 3, supplier_tax_number: "22222222")

        expect(request_body(build_request(built))).to eq(request_body(expected))
      end

      it "builds a minimal request that matches the schema" do
        xml = build_request(operation.new("INV-2026-0001", direction: :outbound))

        expect(xml).to be_valid_nav_xml
        expect(xml).not_to include("batchIndex", "supplierTaxNumber")
      end

      it "rejects invalid parameters" do
        expect { operation.new("", direction: :outbound) }.to raise_error(ArgumentError, /invoice_number/)
        expect { operation.new("X", direction: :up) }.to raise_error(ArgumentError, /direction/)
        expect { operation.new("X", direction: :inbound, batch_index: 0) }.to raise_error(ArgumentError, /batch_index/)
      end
    end
  end
end
