# frozen_string_literal: true

# Hand-written response fixtures must stay valid against NAV's schema.
RSpec.describe "Response fixtures" do # rubocop:disable RSpec/DescribeClass
  Dir[File.join(FixtureHelpers::FIXTURE_DIR, "responses/**/*.xml")].each do |path|
    name = path.delete_prefix("#{FixtureHelpers::FIXTURE_DIR}/")

    it "#{name} matches the NAV schema" do
      expect(File.read(path)).to be_valid_nav_xml
    end
  end
end
