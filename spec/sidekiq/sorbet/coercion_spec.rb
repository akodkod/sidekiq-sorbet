# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet type coercion" do
  # Type coercion happens during deserialization (when job comes from Redis).
  # When enqueuing with run_async/run_sync, T::Struct validates strictly.
  # Coercion is useful because Sidekiq stores everything as JSON, so values
  # may come back as strings when the job is picked up by a worker.

  describe "string to boolean coercion" do
    it "coerces 'true' string to true during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => "true",
        "int_field" => 1,
        "float_field" => 1.0,
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:bool_field]).to be(true)
    end

    it "coerces 'false' string to false during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => "false",
        "int_field" => 1,
        "float_field" => 1.0,
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:bool_field]).to be(false)
    end
  end

  describe "string to integer coercion" do
    it "coerces numeric string to integer during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => "42",
        "float_field" => 1.0,
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:int_field]).to eq(42)
    end

    it "coerces negative numeric string to integer during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => "-123",
        "float_field" => 1.0,
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:int_field]).to eq(-123)
    end
  end

  describe "string to float coercion" do
    it "coerces numeric string to float during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => 1,
        "float_field" => "3.14",
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:float_field]).to eq(3.14)
    end

    it "coerces integer to float during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => 1,
        "float_field" => 42,
        "string_field" => "test",
        "symbol_field" => "test",
      })
      expect(result[:float_field]).to eq(42.0)
    end
  end

  describe "to string coercion" do
    it "coerces integer to string during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => 1,
        "float_field" => 1.0,
        "string_field" => 123,
        "symbol_field" => "test",
      })
      expect(result[:string_field]).to eq("123")
    end

    it "coerces float to string during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => 1,
        "float_field" => 1.0,
        "string_field" => 3.14,
        "symbol_field" => "test",
      })
      expect(result[:string_field]).to eq("3.14")
    end
  end

  describe "string to symbol coercion" do
    it "coerces string to symbol during deserialization" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => true,
        "int_field" => 1,
        "float_field" => 1.0,
        "string_field" => "test",
        "symbol_field" => "my_symbol",
      })
      expect(result[:symbol_field]).to eq(:my_symbol)
    end
  end

  describe "full round-trip coercion" do
    it "handles multiple coercions in a single job" do
      worker = WorkerWithCoercibleTypes.new
      result = worker.perform({
        "bool_field" => "true",
        "int_field" => "99",
        "float_field" => "2.718",
        "string_field" => 42,
        "symbol_field" => "coerced_symbol",
      })

      expect(result[:bool_field]).to be(true)
      expect(result[:int_field]).to eq(99)
      expect(result[:float_field]).to eq(2.718)
      expect(result[:string_field]).to eq("42")
      expect(result[:symbol_field]).to eq(:coerced_symbol)
    end
  end

  describe "coercion errors during deserialization" do
    it "raises SerializationError when string cannot be coerced to integer" do
      worker = WorkerWithCoercibleTypes.new
      expect do
        worker.perform({
          "bool_field" => true,
          "int_field" => "not_a_number",
          "float_field" => 1.0,
          "string_field" => "test",
          "symbol_field" => "test",
        })
      end.to raise_error(Sidekiq::Sorbet::SerializationError, /Failed to deserialize/)
    end

    it "raises SerializationError when string cannot be coerced to float" do
      worker = WorkerWithCoercibleTypes.new
      expect do
        worker.perform({
          "bool_field" => true,
          "int_field" => 1,
          "float_field" => "not_a_float",
          "string_field" => "test",
          "symbol_field" => "test",
        })
      end.to raise_error(Sidekiq::Sorbet::SerializationError, /Failed to deserialize/)
    end

    it "raises SerializationError when string cannot be coerced to boolean" do
      worker = WorkerWithCoercibleTypes.new
      expect do
        worker.perform({
          "bool_field" => "not_a_boolean",
          "int_field" => 1,
          "float_field" => 1.0,
          "string_field" => "test",
          "symbol_field" => "test",
        })
      end.to raise_error(Sidekiq::Sorbet::SerializationError, /Failed to deserialize/)
    end
  end

  describe "strict typing at enqueue time" do
    # When calling run_sync/run_async, T::Struct validates types strictly.
    # Coercion does NOT happen at enqueue time - only during deserialization.

    it "rejects wrong types when enqueuing with run_sync" do
      expect do
        WorkerWithCoercibleTypes.run_sync(
          bool_field: "true", # String instead of boolean
          int_field: 1,
          float_field: 1.0,
          string_field: "test",
          symbol_field: :test,
        )
      end.to raise_error(Sidekiq::Sorbet::InvalidArgsError)
    end

    it "accepts correct types when enqueuing with run_sync" do
      result = WorkerWithCoercibleTypes.run_sync(
        bool_field: true,
        int_field: 42,
        float_field: 3.14,
        string_field: "hello",
        symbol_field: :world,
      )

      expect(result[:bool_field]).to be(true)
      expect(result[:int_field]).to eq(42)
      expect(result[:float_field]).to eq(3.14)
      expect(result[:string_field]).to eq("hello")
      expect(result[:symbol_field]).to eq(:world)
    end
  end
end
