# frozen_string_literal: true

require "spec_helper"
require "sidekiq/sorbet/rspec"

RSpec.describe Sidekiq::Sorbet::RSpec::Matchers do
  describe "#have_arg" do
    describe "with SimpleWorker" do
      it "matches when argument exists with correct type" do
        expect(SimpleWorker).to have_arg(:value, Integer)
      end

      it "matches when argument exists without type check" do
        expect(SimpleWorker).to have_arg(:value)
      end

      it "fails when argument does not exist" do
        expect do
          expect(SimpleWorker).to have_arg(:nonexistent, Integer)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected SimpleWorker::Args to have argument :nonexistent/)
      end

      it "fails when type does not match" do
        expect do
          expect(SimpleWorker).to have_arg(:value, String)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected SimpleWorker::Args argument :value to be String, but was Integer/)
      end
    end

    describe "with WorkerWithDefaults" do
      it "matches argument with default value" do
        expect(WorkerWithDefaults).to have_arg(:optional_field, T::Boolean).with_default(false)
      end

      it "fails when default value does not match" do
        expect do
          expect(WorkerWithDefaults).to have_arg(:optional_field, T::Boolean).with_default(true)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /to have default value true, but was false/)
      end

      it "fails when required argument checked for default" do
        expect do
          expect(WorkerWithDefaults).to have_arg(:required_field, String).with_default("test")
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /to have a default value, but it was required/)
      end
    end

    describe "with WorkerWithComplexTypes" do
      it "matches array type" do
        expect(WorkerWithComplexTypes).to have_arg(:tags, T::Array[String])
      end

      it "matches hash type" do
        expect(WorkerWithComplexTypes).to have_arg(:metadata, T::Hash[String, T.untyped])
      end

      it "matches nilable type" do
        expect(WorkerWithComplexTypes).to have_arg(:priority, T.nilable(Integer))
      end
    end

    describe "negated matcher" do
      it "passes when argument does not exist" do
        expect(SimpleWorker).not_to have_arg(:nonexistent)
      end

      it "fails when argument exists" do
        expect do
          expect(SimpleWorker).not_to have_arg(:value)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected SimpleWorker::Args not to have argument :value/)
      end
    end
  end

  describe "#have_args" do
    describe "with hash syntax" do
      it "matches all arguments with correct types" do
        expect(WorkerWithDefaults).to have_args(
          required_field: String,
          optional_field: T::Boolean,
        )
      end

      it "fails when any argument does not match" do
        expect do
          expect(WorkerWithDefaults).to have_args(
            required_field: Integer,
            optional_field: T::Boolean,
          )
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected WorkerWithDefaults::Args argument :required_field to be Integer/)
      end
    end

    describe "with fluent chain syntax" do
      it "matches arguments using and_arg chain" do
        expect(WorkerWithDefaults)
          .to have_args(:required_field, String)
          .and_arg(:optional_field, T::Boolean)
      end
    end
  end

  describe "#accept_args" do
    describe "with valid arguments" do
      it "passes for SimpleWorker" do
        expect(SimpleWorker).to accept_args(value: 42)
      end

      it "passes for WorkerWithDefaults with required only" do
        expect(WorkerWithDefaults).to accept_args(required_field: "test")
      end

      it "passes for WorkerWithDefaults with all fields" do
        expect(WorkerWithDefaults).to accept_args(required_field: "test", optional_field: true)
      end

      it "passes for WorkerWithComplexTypes" do
        expect(WorkerWithComplexTypes).to accept_args(
          user_id: 123,
          tags: ["a", "b"],
          metadata: { "key" => "value" },
        )
      end

      it "passes for WorkerWithNestedStruct" do
        expect(WorkerWithNestedStruct).to accept_args(
          name: "Alice",
          address: WorkerWithNestedStruct::Address.new(street: "Main St", city: "Portland"),
        )
      end
    end

    describe "negated matcher" do
      it "fails when arguments are accepted" do
        expect do
          expect(SimpleWorker).not_to accept_args(value: 42)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected SimpleWorker not to accept arguments/)
      end
    end
  end

  describe "#reject_args" do
    describe "with invalid arguments" do
      it "passes when wrong type is provided" do
        expect(SimpleWorker).to reject_args(value: "not an integer")
      end

      it "passes when required field is missing" do
        expect(WorkerWithDefaults).to reject_args(optional_field: true)
      end

      it "passes with specific error class" do
        expect(SimpleWorker)
          .to reject_args(value: "not an integer")
          .with_error(Sidekiq::Sorbet::InvalidArgsError)
      end

      it "passes with error class and message pattern" do
        expect(SimpleWorker)
          .to reject_args(value: "not an integer")
          .with_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid arguments/)
      end

      it "fails when error class does not match" do
        expect do
          expect(SimpleWorker)
            .to reject_args(value: "not an integer")
            .with_error(Sidekiq::Sorbet::SerializationError)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected SimpleWorker to raise.*SerializationError.*but raised.*InvalidArgsError/)
      end

      it "fails when message pattern does not match" do
        expect do
          expect(SimpleWorker)
            .to reject_args(value: "not an integer")
            .with_error(Sidekiq::Sorbet::InvalidArgsError, /nonexistent pattern/)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected error message to match/)
      end
    end

    describe "with valid arguments" do
      it "fails when arguments are accepted" do
        expect do
          expect(SimpleWorker).to reject_args(value: 42)
        end.to raise_error(RSpec::Expectations::ExpectationNotMetError,
                           /expected SimpleWorker to reject arguments.*but it accepted them/)
      end
    end

    describe "negated matcher" do
      it "passes when arguments are accepted" do
        expect(SimpleWorker).not_to reject_args(value: 42)
      end
    end
  end
end
