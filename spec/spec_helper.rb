# frozen_string_literal: true

require "nav_online_invoice"
require "webmock/rspec"

Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.filter_run_excluding :integration unless ENV["NAV_INTEGRATION"] == "1"
  config.order = :random
  Kernel.srand config.seed

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
