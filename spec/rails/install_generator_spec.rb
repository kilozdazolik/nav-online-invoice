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

    after { NavOnlineInvoice.reset! }

    it "creates an initializer that is valid Ruby" do
      generate

      expect(RubyVM::InstructionSequence.compile_file(initializer)).to be_a(RubyVM::InstructionSequence)
    end

    def load_with_credentials(nav)
      rails = Module.new
      rails.define_singleton_method(:application) { Struct.new(:credentials).new(Struct.new(:nav).new(nav)) }
      rails.define_singleton_method(:env) { ActiveSupport::StringInquirer.new("development") }
      stub_const("Rails", rails)
      load initializer
    end

    it "builds a valid configuration from the credentials" do
      generate
      load_with_credentials(login: "specuser0000001", password: "secret", signature_key: "spec-signature-key",
                            exchange_key: "spec-exchange-k1", tax_number: "12345678")

      expect(NavOnlineInvoice.configuration).to have_attributes(environment: :test, tax_number: "12345678")
    end

    it "leaves the gem unconfigured instead of stopping the boot when there are no credentials" do
      generate

      expect { load_with_credentials(nil) }.not_to raise_error
      expect { NavOnlineInvoice.configuration }.to raise_error(NavOnlineInvoice::ConfigurationError)
    end
  end
end
