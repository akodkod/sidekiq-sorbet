# typed: true
# frozen_string_literal: true

module Sidekiq
  module Sorbet
    # Base error class for all Sidekiq::Sorbet errors
    class Error < StandardError; end

    # Raised when a worker doesn't define an Args class or it's not a T::Struct
    class ArgsNotDefinedError < Error; end

    # Raised when argument validation fails at enqueue time
    class InvalidArgsError < Error; end

    # Raised when serialization or deserialization fails
    class SerializationError < Error; end
  end
end
