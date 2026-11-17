# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Redactor do
  let(:redacted) { described_class.redact(fixture("requests/query_taxpayer_official.xml")) }

  it "hides the login, the password hash and the signature" do
    expect(redacted).to include(
      "<common:login>[FILTERED]</common:login>",
      '<common:passwordHash cryptoType="SHA-512">[FILTERED]</common:passwordHash>',
      '<common:requestSignature cryptoType="SHA3-512">[FILTERED]</common:requestSignature>'
    )
    expect(redacted).not_to include("lwilsmn0uqdxe6u", "2F43840A", "C5ADE8A2")
  end

  it "hides invoice data and original requests" do
    xml = "<invoiceDataResult><invoiceData>QUJDREVG</invoiceData></invoiceDataResult>" \
          "<ns2:originalRequest>WFla</ns2:originalRequest>"

    expect(described_class.redact(xml)).to eq(
      "<invoiceDataResult><invoiceData>[FILTERED 8 bytes]</invoiceData></invoiceDataResult>" \
      "<ns2:originalRequest>[FILTERED 4 bytes]</ns2:originalRequest>"
    )
  end

  it "keeps everything else" do
    expect(redacted).to include("<common:requestId>RID215118906689</common:requestId>",
                                "<taxNumber>22222222</taxNumber>")
  end
end
