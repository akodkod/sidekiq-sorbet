# frozen_string_literal: true
# typed: false

# Test worker with complex types
class WorkerWithComplexTypes
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :user_id, Integer
    const :tags, T::Array[String], default: []
    const :metadata, T::Hash[String, T.untyped], default: {}
    const :priority, T.nilable(Integer), default: nil
  end

  def run
    {
      user_id: user_id, # Direct access
      tags: tags,
      metadata: metadata,
      priority: priority,
    }
  end
end

# Test worker for type coercion tests
class WorkerWithCoercibleTypes
  include Sidekiq::Sorbet

  class Args < T::Struct
    const :bool_field, T::Boolean
    const :int_field, Integer
    const :float_field, Float
    const :string_field, String
    const :symbol_field, Symbol
  end

  def run
    {
      bool_field: bool_field,
      int_field: int_field,
      float_field: float_field,
      string_field: string_field,
      symbol_field: symbol_field,
    }
  end
end

# Test worker with nested T::Struct
class WorkerWithNestedStruct
  include Sidekiq::Sorbet

  class Address < T::Struct
    const :street, String
    const :city, String
  end

  class Args < T::Struct
    const :name, String
    const :address, Address
  end

  def run
    "#{name} lives at #{address.street}, #{address.city}" # Direct access
  end
end
