# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet argument access" do
  describe "args accessor (backward compatibility)" do
    it "provides access to typed arguments" do
      worker = SimpleWorker.new
      worker.instance_variable_set(:@args, SimpleWorker::Args.new(value: 10))
      worker.define_arg_accessors

      expect(worker.args.value).to eq(10)
    end

    it "returns nil if args not initialized" do
      worker = SimpleWorker.new
      expect(worker.args).to be_nil
    end

    it "works with args accessor in run method" do
      result = WorkerUsingArgsAccessor.run_sync(value: 5)
      expect(result).to eq(15)
    end
  end

  describe "direct argument access" do
    it "provides direct access to argument fields" do
      result = SimpleWorker.run_sync(value: 7)
      expect(result).to eq(14)
    end

    it "works with nested struct fields" do
      result = WorkerWithNestedStruct.run_sync(
        name: "Alice",
        address: WorkerWithNestedStruct::Address.new(
          street: "Main St",
          city: "Portland",
        ),
      )
      expect(result).to eq("Alice lives at Main St, Portland")
    end

    it "works with complex types" do
      result = WorkerWithComplexTypes.run_sync(
        user_id: 99,
        tags: ["test"],
        metadata: { "key" => "val" },
      )
      expect(result[:user_id]).to eq(99)
      expect(result[:tags]).to eq(["test"])
    end
  end

  describe "nested T::Struct support" do
    it "handles nested T::Structs when passed as instances" do
      address = WorkerWithNestedStruct::Address.new(
        street: "123 Main St",
        city: "Portland",
      )
      result = WorkerWithNestedStruct.run_sync(
        name: "John",
        address: address,
      )

      expect(result).to eq("John lives at 123 Main St, Portland")
    end

    it "handles nested T::Structs via async (from_hash handles conversion)" do
      expect do
        WorkerWithNestedStruct.run_async(
          name: "John",
          address: WorkerWithNestedStruct::Address.new(
            street: "456 Oak Ave",
            city: "Seattle",
          ),
        )
      end.not_to raise_error
    end

    it "validates nested struct types" do
      expect do
        WorkerWithNestedStruct.run_sync(
          name: "John",
          address: "not an address",
        )
      end.to raise_error(Sidekiq::Sorbet::InvalidArgsError)
    end
  end
end
