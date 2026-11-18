# frozen_string_literal: true

begin
  require "rails/generators"
rescue LoadError
  # Rails is not in this bundle; these specs run with gemfiles/rails_8_1.gemfile.
end

if defined?(Rails::Generators)
  require "tmpdir"
  require "generators/nav_online_invoice/install/install_generator"

  RSpec.describe NavOnlineInvoice::Generators::InstallGenerator do
    around do |example|
      Dir.mktmpdir do |dir|
        @root = dir
        example.run
      end
    end

    let(:initializer) { File.join(@root, "config/initializers/nav_online_invoice.rb") }

    def generate
      described_class.start([], destination_root: @root, quiet: true)
    end

    it "creates an initializer that is valid Ruby" do
      generate

      expect(RubyVM::InstructionSequence.compile_file(initializer)).to be_a(RubyVM::InstructionSequence)
    end

    it "builds a valid configuration from the credentials" do
      generate
      credentials = { login: "specuser0000001", password: "secret", signature_key: "spec-signature-key",
                      exchange_key: "spec-exchange-k1", tax_number: "12345678" }
      rails = Module.new
      rails.define_singleton_method(:application) { Struct.new(:credentials).new(Struct.new(:nav).new(credentials)) }
      rails.define_singleton_method(:env) { ActiveSupport::StringInquirer.new("development") }
      stub_const("Rails", rails)

      load initializer

      expect(NavOnlineInvoice.configuration).to have_attributes(environment: :test, tax_number: "12345678")
    ensure
      NavOnlineInvoice.reset!
    end
  end
end
