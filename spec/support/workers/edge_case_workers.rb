# frozen_string_literal: true
# typed: false

# Test worker without Args class (now allowed!)
class WorkerWithoutArgs
  include Sidekiq::Sorbet

  def run
    "works without args"
  end
end

# Test worker with all optional Args
class WorkerWithAllOptionalArgs
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :optional_value, T.nilable(Integer), default: nil
    const :optional_flag, T::Boolean, default: false
  end

  def run
    "optional_value: #{optional_value}, optional_flag: #{optional_flag}"
  end
end

# Test worker that doesn't implement run (for error testing)
class WorkerWithoutRun
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :value, Integer
  end

  # Intentionally not implementing run
end
