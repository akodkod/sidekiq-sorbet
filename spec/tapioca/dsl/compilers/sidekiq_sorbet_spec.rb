# frozen_string_literal: true

RSpec.describe Tapioca::Dsl::Compilers::SidekiqSorbet do
  describe ".gather_constants" do
    it "detects all Sidekiq::Sorbet workers" do
      constants = described_class.gather_constants
      expect(constants).to include(SimpleWorker)
      expect(constants).to include(WorkerWithDefaults)
      expect(constants).to include(WorkerWithComplexTypes)
      expect(constants).to include(WorkerWithoutArgs)
    end

    it "only detects classes that include Sidekiq::Sorbet" do
      constants = described_class.gather_constants
      # All detected constants should be classes
      expect(constants.all?(Class)).to be true
      # All should include Sidekiq::Sorbet
      expect(constants.all? { |c| c.included_modules.include?(Sidekiq::Sorbet) }).to be true
    end

    it "is registered as a Tapioca DSL compiler" do
      expect(described_class).to be < Tapioca::Dsl::Compiler
    end
  end

  describe "#decorate" do
    let(:rbi) { RBI::Tree.new }

    def compile(worker_class)
      compiler = described_class.new(
        Tapioca::Dsl::Pipeline.new(requested_constants: [worker_class]),
        rbi,
        worker_class,
        [],
      )
      compiler.decorate
      rbi.string
    end

    context "with SimpleWorker" do
      it "generates instance accessor and class methods" do
        output = compile(SimpleWorker)

        expect(output).to include("class SimpleWorker")
        # Instance accessor for the arg
        expect(output).to include("sig { returns(Integer) }")
        expect(output).to include("def value; end")
        # Class methods
        expect(output).to include("sig { params(value: Integer).returns(String) }")
        expect(output).to include("def self.run_async(value:); end")
        expect(output).to include("sig { params(time: T.any(Time, Numeric), value: Integer).returns(String) }")
        expect(output).to include("def self.run_at(time, value:); end")
        expect(output).to include("sig { params(interval: Numeric, value: Integer).returns(String) }")
        expect(output).to include("def self.run_in(interval, value:); end")
        expect(output).to include("sig { params(value: Integer).returns(T.untyped) }")
        expect(output).to include("def self.run_sync(value:); end")
      end
    end

    context "with WorkerWithDefaults" do
      it "generates keyword args with defaults for optional fields" do
        output = compile(WorkerWithDefaults)

        expect(output).to include("class WorkerWithDefaults")
        # Required field - no default
        expect(output).to include("sig { returns(String) }")
        expect(output).to include("def required_field; end")
        # Optional field - with default
        expect(output).to include("sig { returns(T::Boolean) }")
        expect(output).to include("def optional_field; end")
        # Class methods with mixed required/optional kwargs
        expect(output).to include("sig { params(required_field: String, optional_field: T::Boolean).returns(String) }")
        expect(output).to include("def self.run_async(required_field:, optional_field: T.unsafe(nil)); end")
      end
    end

    context "with WorkerWithComplexTypes" do
      it "generates correct signatures for complex types" do
        output = compile(WorkerWithComplexTypes)

        expect(output).to include("class WorkerWithComplexTypes")
        # Check complex type signatures
        expect(output).to include("sig { returns(Integer) }")
        expect(output).to include("def user_id; end")
        expect(output).to include("sig { returns(T::Array[String]) }")
        expect(output).to include("def tags; end")
        expect(output).to include("sig { returns(T::Hash[String, T.untyped]) }")
        expect(output).to include("def metadata; end")
        expect(output).to include("sig { returns(T.nilable(Integer)) }")
        expect(output).to include("def priority; end")
      end
    end

    context "with WorkerWithoutArgs" do
      it "generates class methods with no parameters" do
        output = compile(WorkerWithoutArgs)

        expect(output).to include("class WorkerWithoutArgs")
        # No instance accessors (no Args class)
        expect(output).not_to include("def value; end")
        # Class methods with no params
        expect(output).to include("sig { returns(String) }")
        expect(output).to include("def self.run_async; end")
        expect(output).to include("sig { params(time: T.any(Time, Numeric)).returns(String) }")
        expect(output).to include("def self.run_at(time); end")
        expect(output).to include("sig { params(interval: Numeric).returns(String) }")
        expect(output).to include("def self.run_in(interval); end")
        expect(output).to include("sig { returns(T.untyped) }")
        expect(output).to include("def self.run_sync; end")
      end
    end

    context "with WorkerWithAllOptionalArgs" do
      it "generates all kwargs with defaults" do
        output = compile(WorkerWithAllOptionalArgs)

        expect(output).to include("class WorkerWithAllOptionalArgs")
        # All fields have defaults
        expect(output).to include("def self.run_async(optional_value: T.unsafe(nil), optional_flag: T.unsafe(nil)); end") # rubocop:disable Layout/LineLength
        expect(output).to include("def self.run_sync(optional_value: T.unsafe(nil), optional_flag: T.unsafe(nil)); end")
      end
    end

    context "with WorkerWithNestedStruct" do
      it "generates correct signature for nested T::Struct" do
        output = compile(WorkerWithNestedStruct)

        expect(output).to include("class WorkerWithNestedStruct")
        # Nested struct type should be referenced directly
        expect(output).to include("sig { returns(WorkerWithNestedStruct::Address) }")
        expect(output).to include("def address; end")
        expect(output).to include("sig { returns(String) }")
        expect(output).to include("def name; end")
      end
    end
  end
end
