# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet enqueueing jobs" do
  describe ".run_async" do
    context "with valid arguments" do
      it "enqueues a job" do
        expect do
          SimpleWorker.run_async(value: 10)
        end.not_to raise_error
      end

      it "returns a job ID" do
        jid = SimpleWorker.run_async(value: 10)
        expect(jid).to be_a(String)
        expect(jid).not_to be_empty
      end

      it "validates arguments before enqueueing" do
        expect do
          SimpleWorker.run_async(value: 5)
        end.not_to raise_error
      end
    end

    context "with default values" do
      it "works when optional field is omitted" do
        expect do
          WorkerWithDefaults.run_async(required_field: "test")
        end.not_to raise_error
      end

      it "works when optional field is provided" do
        expect do
          WorkerWithDefaults.run_async(required_field: "test", optional_field: true)
        end.not_to raise_error
      end
    end

    context "with complex types" do
      it "handles arrays" do
        expect do
          WorkerWithComplexTypes.run_async(user_id: 1, tags: ["a", "b"])
        end.not_to raise_error
      end

      it "handles hashes" do
        expect do
          WorkerWithComplexTypes.run_async(user_id: 1, metadata: { "key" => "value" })
        end.not_to raise_error
      end

      it "handles nil values" do
        expect do
          WorkerWithComplexTypes.run_async(user_id: 1, priority: nil)
        end.not_to raise_error
      end
    end

    context "with invalid arguments" do
      it "raises InvalidArgsError for wrong type" do
        expect do
          SimpleWorker.run_async(value: "not an integer")
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid arguments/)
      end

      it "raises InvalidArgsError for missing required field" do
        expect do
          WorkerWithDefaults.run_async(optional_field: true)
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid arguments/)
      end

      it "provides helpful error message" do
        expect do
          SimpleWorker.run_async(value: "wrong")
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError, /SimpleWorker/)
      end
    end
  end

  describe ".run_at" do
    context "with valid arguments" do
      it "schedules a job at a specific time" do
        time = Time.now + 3600
        expect do
          SimpleWorker.run_at(time, value: 10)
        end.not_to raise_error
      end

      it "returns a job ID" do
        time = Time.now + 3600
        jid = SimpleWorker.run_at(time, value: 10)
        expect(jid).to be_a(String)
        expect(jid).not_to be_empty
      end

      it "accepts numeric timestamp" do
        timestamp = Time.now.to_f + 3600
        expect do
          SimpleWorker.run_at(timestamp, value: 10)
        end.not_to raise_error
      end

      it "validates arguments before scheduling" do
        time = Time.now + 3600
        expect do
          SimpleWorker.run_at(time, value: "not an integer")
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid arguments/)
      end
    end

    context "with default values" do
      it "works when optional field is omitted" do
        time = Time.now + 3600
        expect do
          WorkerWithDefaults.run_at(time, required_field: "test")
        end.not_to raise_error
      end
    end
  end

  describe ".run_in" do
    context "with valid arguments" do
      it "schedules a job after a delay" do
        expect do
          SimpleWorker.run_in(3600, value: 10)
        end.not_to raise_error
      end

      it "returns a job ID" do
        jid = SimpleWorker.run_in(3600, value: 10)
        expect(jid).to be_a(String)
        expect(jid).not_to be_empty
      end

      it "accepts float interval" do
        expect do
          SimpleWorker.run_in(3600.5, value: 10)
        end.not_to raise_error
      end

      it "validates arguments before scheduling" do
        expect do
          SimpleWorker.run_in(3600, value: "not an integer")
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid arguments/)
      end
    end

    context "with default values" do
      it "works when optional field is omitted" do
        expect do
          WorkerWithDefaults.run_in(3600, required_field: "test")
        end.not_to raise_error
      end
    end
  end

  describe ".run_sync" do
    context "with valid arguments" do
      it "executes the job synchronously" do
        result = SimpleWorker.run_sync(value: 5)
        expect(result).to eq(10)
      end

      it "returns the result of the run method" do
        result = WorkerWithDefaults.run_sync(required_field: "test")
        expect(result).to eq("test: false")
      end

      it "works with default values" do
        result = WorkerWithDefaults.run_sync(required_field: "hello", optional_field: true)
        expect(result).to eq("hello: true")
      end
    end

    context "with complex types" do
      it "correctly passes all arguments" do
        result = WorkerWithComplexTypes.run_sync(
          user_id: 42,
          tags: ["ruby", "rails"],
          metadata: { "source" => "test" },
          priority: 5,
        )

        expect(result).to eq({
          user_id: 42,
          tags: ["ruby", "rails"],
          metadata: { "source" => "test" },
          priority: 5,
        })
      end
    end

    context "with invalid arguments" do
      it "raises InvalidArgsError for wrong type" do
        expect do
          SimpleWorker.run_sync(value: "not an integer")
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError)
      end

      it "raises InvalidArgsError for missing required field" do
        expect do
          WorkerWithDefaults.run_sync(optional_field: true)
        end.to raise_error(Sidekiq::Sorbet::InvalidArgsError)
      end
    end
  end

  describe "serialization and deserialization" do
    it "correctly serializes and deserializes simple types" do
      result = SimpleWorker.run_sync(value: 42)
      expect(result).to eq(84)
    end

    it "correctly serializes and deserializes complex types" do
      result = WorkerWithComplexTypes.run_sync(
        user_id: 1,
        tags: ["a", "b", "c"],
        metadata: { "key" => "value" },
      )

      expect(result[:tags]).to eq(["a", "b", "c"])
      expect(result[:metadata]).to eq({ "key" => "value" })
    end

    it "correctly handles default values during serialization" do
      result = WorkerWithDefaults.run_sync(required_field: "test")
      expect(result).to include("false")
    end
  end
end
