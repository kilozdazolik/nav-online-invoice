# frozen_string_literal: true

module NavOnlineInvoice
  InvoiceParty = Data.define(:tax_number, :group_member_tax_number, :community_vat_number, :third_state_tax_id,
                             :name, :address, :bank_account_number, :vat_status)

  # The supplier, the customer or the fiscal representative of an invoice, as the invoice states them.
  #
  # @!attribute tax_number
  #   @return [String, nil] e.g. "12345678-2-42", or the 8 digits if the codes are missing; nil for a foreign or
  #     private customer
  # @!attribute group_member_tax_number
  #   @return [String, nil] the member's tax number, for a VAT group
  # @!attribute community_vat_number
  #   @return [String, nil] EU VAT number, e.g. "HU12345678"
  # @!attribute third_state_tax_id
  #   @return [String, nil] a customer's tax ID outside the EU
  # @!attribute name
  #   @return [String, nil] nil for a private customer
  # @!attribute address
  #   @return [Address, nil] nil for a private customer
  # @!attribute bank_account_number
  #   @return [String, nil] as written on the invoice: "12345678-12345678", "12345678-12345678-12345678" or an IBAN
  # @!attribute vat_status
  #   @return [Symbol, nil] for the customer only: `:domestic`, `:other` (foreign) or `:private_person`
  class InvoiceParty
    include Redacted
    include DeepHash

    def initialize(tax_number: nil, group_member_tax_number: nil, community_vat_number: nil, third_state_tax_id: nil,
                   name: nil, address: nil, bank_account_number: nil, vat_status: nil)
      super
    end

    # Leaves out every identifying field: for a sole trader or a private person they are personal data.
    def inspect = "#<data #{self.class.name} vat_status=#{vat_status.inspect}>"
  end
end
