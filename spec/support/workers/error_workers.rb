# frozen_string_literal: true
# typed: false

# Test worker with invalid Args (not a T::Struct)
class WorkerWithInvalidArgs
  include Sidekiq::Sorbet

  # rubocop:disable Lint/EmptyClass
  class Args
  end
  # rubocop:enable Lint/EmptyClass

  def run
    "should not work"
  end
end

# Test worker that raises an error in run
class WorkerThatRaisesError
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :message, String
  end

  def run
    raise StandardError, message # Direct access
  end
end

# Test worker with Args that has a custom serialization issue
class WorkerWithSerializationError
  include Sidekiq::Sorbet

  class BadArgs < T::Struct
    const :value, Integer

    # Override serialize to cause an error
    def serialize
      raise StandardError, "Serialization failed!"
    end
  end

  # Alias Args to BadArgs
  Args = BadArgs

  def run
    "never called"
  end
end

# Test worker with Args that has deserialization issues
class WorkerWithDeserializationError
  include Sidekiq::Sorbet

  class BadArgs < T::Struct
    const :value, Integer

    # Override from_hash to cause an error
    def self.from_hash(_hash)
      raise StandardError, "Deserialization failed!"
    end
  end

  Args = BadArgs

  def run
    "never called"
  end
end
