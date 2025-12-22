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
# Note: With HashSerializer, serialization of valid structs doesn't fail,
# so we use an invalid schema setup to trigger errors
class WorkerWithSerializationError
  include Sidekiq::Sorbet

  class BadArgs < T::Struct
    const :value, Integer

    # Override schema to return nil, which will cause HashSerializer to fail
    def self.schema
      nil
    end
  end

  # Alias Args to BadArgs
  Args = BadArgs

  def run
    "never called"
  end
end

# Test worker with Args that has deserialization issues
# HashSerializer fails when required fields are missing or types can't be coerced
class WorkerWithDeserializationError
  include Sidekiq::Sorbet

  class BadArgs < T::Struct
    const :value, Integer
    const :required_field, String # This will cause deserialization to fail if missing
  end

  Args = BadArgs

  def run
    "never called"
  end
end
