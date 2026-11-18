# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::ApiError do
  describe ".for" do
    {
      "INVALID_SECURITY_USER" => NavOnlineInvoice::AuthenticationError,
      "INVALID_REQUEST_SIGNATURE" => NavOnlineInvoice::AuthenticationError,
      "FORBIDDEN" => NavOnlineInvoice::PermissionError,
      "INVALID_USER_RELATION" => NavOnlineInvoice::CustomerError,
      "INVALID_PREDECESSOR_TAX_NUMBER" => NavOnlineInvoice::CustomerError,
      "INVALID_TIMESTAMP" => NavOnlineInvoice::RequestError,
      "NOT_ALLOWED_EXCEPTION" => NavOnlineInvoice::RequestError,
      "BAD_QUERY_PARAM_OVERLAP" => NavOnlineInvoice::RequestError,
      "INVALID_EXCHANGE_TOKEN" => NavOnlineInvoice::ExchangeTokenError,
      "MAINTENANCE_MODE" => NavOnlineInvoice::MaintenanceError,
      "OPERATION_FAILED" => NavOnlineInvoice::TemporaryError,
      "REQUEST_ID_NOT_UNIQUE" => NavOnlineInvoice::TemporaryError
    }.each do |code, klass|
      it "maps #{code} to #{klass.name.split("::").last}" do
        expect(described_class.for(code)).to eq(klass)
      end
    end

    it "maps unknown and missing codes to ApiError" do
      expect([described_class.for("SOMETHING_NEW"), described_class.for(nil)]).to all(eq(described_class))
    end
  end

  it "keeps a rejected exchange token out of RequestError, since resubmitting is safe" do
    expect(NavOnlineInvoice::ExchangeTokenError.ancestors).not_to include(NavOnlineInvoice::RequestError)
    expect(described_class::TechnicalValidationMessage).to be(NavOnlineInvoice::TechnicalValidationMessage)
  end

  describe "#retryable?" do
    it "is true only for temporary failures, maintenance and rejected exchange tokens" do
      retryable = [NavOnlineInvoice::TemporaryError, NavOnlineInvoice::MaintenanceError,
                   NavOnlineInvoice::ExchangeTokenError]
      others = [described_class, NavOnlineInvoice::PermissionError, NavOnlineInvoice::AuthenticationError]

      expect(retryable.map { |k| k.new(code: "X").retryable? }).to all(be(true))
      expect(others.map { |k| k.new(code: "X").retryable? }).to all(be(false))
    end
  end

  describe "#message" do
    it "includes the code, NAV's text and the request ID" do
      error = NavOnlineInvoice::PermissionError.new(code: "FORBIDDEN", nav_message: "Jogosultság szükséges!",
                                                    request_id: "RID1")

      expect(error.message).to eq("FORBIDDEN: Jogosultság szükséges! (request_id=RID1)")
    end
  end
end
