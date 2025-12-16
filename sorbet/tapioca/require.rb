# typed: true
# frozen_string_literal: true

# Add your extra requires here (`bin/tapioca require` can be used to bootstrap this list)
require "sidekiq"
require "sidekiq/sorbet"

# Load test workers for DSL generation
Dir[File.join(__dir__, "../../spec/support/workers/**/*.rb")].each { |file| require file }
