# frozen_string_literal: true

RSpec.describe NavOnlineInvoice::Crypto do
  describe ".password_hash" do
    it "returns the uppercase SHA-512 hex digest" do
      expect(described_class.password_hash("abc")).to eq(
        "DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA20A9EEEE64B55D39A" \
        "2192992A274FC1A836BA3C23A3FEEBBD454D4423643CE80E2A9AC94FA54CA49F"
      )
    end
  end

  describe ".request_signature" do
    it "matches NAV's official queryTaxpayer sample" do
      time = Time.utc(2019, 9, 11, 11, 11, 8.579r)

      expect(described_class.request_signature("RID215118906689", time, "ac-ac3a-7f661bff7d342N43CYX4U9FG")).to eq(
        "C5ADE8A2231C509D2887E6C2C4406CC5F72CA25B070AD3E94FADFA3F91A8A366" \
        "7AF882DEDC7D67E9086E3D34A95886E929ACD8C924CD1E8357C89BEF43BA9126"
      )
    end

    it "matches NAV's official manageInvoice example (spec 1.5.1)" do
      index_hashes = [
        described_class.index_hash("CREATE", "QWJjZDEyMzQ="),
        described_class.index_hash("MODIFY", "RGNiYTQzMjE=")
      ]
      time = Time.utc(2017, 12, 30, 18, 25, 45)
      expected = "60BC80609EE3B8F42FE904200A49A1921A1DADA08D55319ACD40C59F626514B7" \
                 "4EEA49011D372600A10DBCF8199D590DA9C2841D987308F2D83DAE17C2470C42"

      signature = described_class.request_signature("TSTKFT1222564", time, "ce-8f5e-215119fa7dd621DLMRHRLH2S",
                                                    index_hashes:)

      expect(signature).to eq(expected)
    end

    it "uses the UTC time of a local timestamp" do
      local = Time.new(2019, 9, 11, 13, 11, 8, "+02:00")

      expect(described_class.request_signature("RID215118906689", local, "ac-ac3a-7f661bff7d342N43CYX4U9FG"))
        .to start_with("C5ADE8A2")
    end
  end

  describe ".decrypt_token" do
    let(:key) { "spec-exchange-k1" }

    def encrypt(token, key)
      cipher = OpenSSL::Cipher.new("AES-128-ECB").encrypt
      cipher.key = key
      [cipher.update(token) + cipher.final].pack("m0")
    end

    it "decrypts a token encrypted with AES-128-ECB" do
      expect(described_class.decrypt_token("RPhlHKAJqPKVpOhEjIfPAHYVFPFtVMDB+nVG5+0lomY=", key))
        .to eq("SPEC-TOKEN-0123456789-ABCDEF")
    end

    it "round-trips a token and accepts line breaks in the base64" do
      encoded = encrypt("2E0B4C6F-SPEC", key).scan(/.{1,8}/).join("\n")

      expect(described_class.decrypt_token(encoded, key)).to eq("2E0B4C6F-SPEC")
    end

    it "rejects a token encrypted with another key" do
      expect { described_class.decrypt_token(encrypt("SPEC-TOKEN", "another-key-0000"), key) }
        .to raise_error(NavOnlineInvoice::DecodeError, /exchange_key/)
    end

    it "rejects a decrypted value that cannot be a token" do
      expect { described_class.decrypt_token(encrypt("x" * 51, key), key) }
        .to raise_error(NavOnlineInvoice::DecodeError)
      expect { described_class.decrypt_token(encrypt(" ", key), key) }.to raise_error(NavOnlineInvoice::DecodeError)
    end

    it "rejects data that is not base64 or not a whole block" do
      expect { described_class.decrypt_token("not base64!", key) }.to raise_error(NavOnlineInvoice::DecodeError)
      expect { described_class.decrypt_token(["short"].pack("m0"), key) }
        .to raise_error(NavOnlineInvoice::DecodeError)
    end
  end
end
