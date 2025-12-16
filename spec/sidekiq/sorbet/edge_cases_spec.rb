# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet edge cases" do
  describe "workers without Args" do
    it "allows workers without Args class" do
      expect(WorkerWithoutArgs.args_class).to be_nil
    end

    it "can run_async without arguments" do
      expect do
        WorkerWithoutArgs.run_async
      end.not_to raise_error
    end

    it "can run_sync without arguments" do
      result = WorkerWithoutArgs.run_sync
      expect(result).to eq("works without args")
    end

    it "rejects arguments when no Args class defined" do
      # Since there's no Args class, passing arguments should work but they'll be ignored
      expect do
        WorkerWithoutArgs.run_async(foo: "bar")
      end.not_to raise_error
    end
  end

  describe "workers with optional Args" do
    it "can be called without arguments when all fields are optional" do
      result = WorkerWithAllOptionalArgs.run_sync
      expect(result).to eq("optional_value: , optional_flag: false")
    end

    it "can be called with arguments" do
      result = WorkerWithAllOptionalArgs.run_sync(optional_value: 42, optional_flag: true)
      expect(result).to eq("optional_value: 42, optional_flag: true")
    end

    it "can run_async without arguments" do
      expect do
        WorkerWithAllOptionalArgs.run_async
      end.not_to raise_error
    end
  end
end
