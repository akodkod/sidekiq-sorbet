# frozen_string_literal: true

require "simplecov"
SimpleCov.start

require "sidekiq/sorbet"
require "sidekiq/testing"

# Load all test workers
Dir[File.join(__dir__, "support/workers/**/*.rb")].each { |file| require file }

# Use inline mode so jobs execute immediately for testing
Sidekiq::Testing.inline!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
