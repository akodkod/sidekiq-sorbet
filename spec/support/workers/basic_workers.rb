# frozen_string_literal: true
# typed: false

# Test worker with simple integer argument
class SimpleWorker
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :value, Integer
  end

  def run
    value * 2 # Direct access instead of args.value
  end
end

# Test worker with default values
class WorkerWithDefaults
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :required_field, String
    const :optional_field, T::Boolean, default: false
  end

  def run
    "#{required_field}: #{optional_field}" # Direct access
  end
end
