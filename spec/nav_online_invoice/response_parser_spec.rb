# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::ResponseParser do
  def parse(body, status: 200)
    described_class.parse(NavOnlineInvoice::Transport::Response.new(status:, body:),
                          expected_root: "QueryTaxpayerResponse", request_id: "RID1")
  end

  it "returns the document of a successful answer" do
    document = parse(fixture("responses/query_taxpayer/valid.xml"))

    expect(document.root.name).to eq("QueryTaxpayerResponse")
  end

  {
    "general_error/forbidden.xml" => [500, NavOnlineInvoice::PermissionError, "FORBIDDEN"],
    "general_error/invalid_security_user.xml" => [401, NavOnlineInvoice::AuthenticationError, "INVALID_SECURITY_USER"],
    "general_error/operation_failed.xml" => [500, NavOnlineInvoice::TemporaryError, "OPERATION_FAILED"],
    "general_error/maintenance_mode.xml" => [503, NavOnlineInvoice::MaintenanceError, "MAINTENANCE_MODE"],
    "general_exception/invalid_request.xml" => [400, NavOnlineInvoice::RequestError, "INVALID_REQUEST"]
  }.each do |path, (status, klass, code)|
    it "raises #{klass.name.split("::").last} for #{path}" do
      expect { parse(fixture("responses/#{path}"), status:) }.to raise_error(klass) { |error|
        expect([error.code, error.request_id, error.http_status]).to eq([code, "RID1", status])
        expect(error.nav_message).not_to be_empty
      }
    end
  end

  it "keeps the technical validation messages" do
    expect { parse(fixture("responses/general_error/technical_validation.xml"), status: 400) }
      .to raise_error(NavOnlineInvoice::RequestError) { |error|
        expect(error.technical_validation_messages).to contain_exactly(
          have_attributes(result_code: "ERROR", error_code: "SCHEMA_VIOLATION", message: /taxNumber/)
        )
      }
  end

  it "raises when the expected answer reports an error" do
    body = fixture("responses/query_taxpayer/valid.xml")
           .sub("<ns2:funcCode>OK</ns2:funcCode>", "<ns2:funcCode>ERROR</ns2:funcCode><ns2:errorCode>X</ns2:errorCode>")

    expect { parse(body) }.to raise_error(NavOnlineInvoice::ApiError, /\AX/)
  end

  it "treats a plain-text 500 as a client error that is not retried" do
    expect { parse(fixture("responses/non_xml/undertow_500.txt"), status: 500) }
      .to raise_error(NavOnlineInvoice::TransportError, /HTTP 500/) { |error| expect(error).not_to be_retryable }
  end

  it "treats an empty 404 as a client error that is not retried" do
    expect { parse("", status: 404) }
      .to raise_error(NavOnlineInvoice::TransportError) { |error| expect(error).not_to be_retryable }
  end

  it "treats an empty 503 as maintenance" do
    expect { parse("", status: 503) }.to raise_error(NavOnlineInvoice::MaintenanceError, &:retryable?)
  end

  it "treats an empty 504 as a retryable transport error" do
    expect { parse("", status: 504) }.to raise_error(NavOnlineInvoice::TransportError, &:retryable?)
  end

  it "treats an HTML page at 503 as maintenance and at 504 as retryable" do
    page = "<html><body><h1>Service Unavailable</h1></body></html>"

    expect { parse(page, status: 503) }.to raise_error(NavOnlineInvoice::MaintenanceError)
    expect { parse(page, status: 504) }.to raise_error(NavOnlineInvoice::TransportError, &:retryable?)
  end

  it "handles a body that is not UTF-8" do
    latin2 = "<html>szolg\xE1ltat\xE1s</html>".dup.force_encoding(Encoding::UTF_8)

    expect { parse(latin2, status: 502) }.to raise_error(NavOnlineInvoice::TransportError, &:retryable?)
  end

  it "reads XML in the encoding its declaration names" do
    body = fixture("responses/query_taxpayer/valid.xml").sub('encoding="UTF-8"', 'encoding="ISO-8859-2"')
                                                        .encode(Encoding::ISO_8859_2).force_encoding(Encoding::UTF_8)

    expect(parse(body).root.name).to eq("QueryTaxpayerResponse")
  end

  it "rejects an unexpected root element" do
    expect { parse(%(<Other xmlns="#{NavOnlineInvoice::NAMESPACES["api"]}"/>)) }
      .to raise_error(NavOnlineInvoice::TransportError, /Unexpected Other/)
  end

  it "does not expand external entities" do
    body = <<~XML
      <?xml version="1.0"?>
      <!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]>
      <QueryTaxpayerResponse xmlns="#{NavOnlineInvoice::NAMESPACES["api"]}">&x;</QueryTaxpayerResponse>
    XML

    expect { parse(body) }.to raise_error(NavOnlineInvoice::ApiError) { |error| expect(error.message).not_to include("root:") }
  end
end
