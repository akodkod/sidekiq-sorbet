# frozen_string_literal: true
# typed: false

# Test worker to verify backward compatibility with args accessor
class WorkerUsingArgsAccessor
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :value, Integer
  end

  def run
    args.value * 3 # Using args accessor (backward compatibility)
  end
end
