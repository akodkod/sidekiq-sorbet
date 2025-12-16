# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet Args class detection" do
  describe ".args_class" do
    context "with valid Args class" do
      it "detects and returns the Args class" do
        expect(SimpleWorker.args_class).to eq(SimpleWorker::Args)
      end

      it "validates that Args is a T::Struct" do
        expect(SimpleWorker::Args).to be < T::Struct
      end
    end

    context "without Args class" do
      it "returns nil (Args is now optional)" do
        expect(WorkerWithoutArgs.args_class).to be_nil
      end
    end

    context "with invalid Args class" do
      it "raises ArgsNotDefinedError" do
        expect do
          WorkerWithInvalidArgs.args_class
        end.to raise_error(Sidekiq::Sorbet::ArgsNotDefinedError, /must inherit from T::Struct/)
      end
    end
  end
end
