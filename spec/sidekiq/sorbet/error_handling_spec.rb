# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet error handling" do
  describe "#run method errors" do
    it "raises NotImplementedError if not overridden" do
      worker = WorkerWithoutRun.new
      worker.instance_variable_set(:@args, WorkerWithoutRun::Args.new(value: 1))

      expect do
        worker.run
      end.to raise_error(NotImplementedError, /must implement #run method/)
    end

    it "executes custom implementation when provided" do
      result = SimpleWorker.run_sync(value: 7)
      expect(result).to eq(14)
    end
  end

  describe "serialization errors" do
    it "raises SerializationError when serialize fails during run_async" do
      expect do
        WorkerWithSerializationError.run_async(value: 1)
      end.to raise_error(Sidekiq::Sorbet::SerializationError, /Failed to serialize/)
    end

    it "raises SerializationError when deserialize fails during perform" do
      worker = WorkerWithDeserializationError.new

      expect do
        worker.perform({ "value" => 1 })
      end.to raise_error(Sidekiq::Sorbet::SerializationError, /Failed to deserialize/)
    end
  end

  describe "unreachable code paths (for 100% coverage)" do
    it "covers WorkerWithInvalidArgs run method" do
      worker = WorkerWithInvalidArgs.new
      expect(worker.run).to eq("should not work")
    end

    it "covers WorkerWithSerializationError run method" do
      worker = WorkerWithSerializationError.new
      expect(worker.run).to eq("never called")
    end

    it "covers WorkerWithDeserializationError run method" do
      worker = WorkerWithDeserializationError.new
      expect(worker.run).to eq("never called")
    end
  end
end
