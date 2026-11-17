# frozen_string_literal: true

module FixtureHelpers
  FIXTURE_DIR = File.expand_path("../fixtures", __dir__)

  def fixture(path)
    File.read(File.join(FIXTURE_DIR, path))
  end
end

RSpec.configure do |config|
  config.include FixtureHelpers
end

RSpec::Matchers.define :be_valid_nav_xml do |schema = :api|
  match { |xml| (@errors = NavOnlineInvoice::SchemaValidator.errors(xml, schema:)).empty? }
  failure_message { "expected XML to match the NAV schema, got:\n  #{@errors.join("\n  ")}" }
end
