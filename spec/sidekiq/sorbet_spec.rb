# frozen_string_literal: true

RSpec.describe Sidekiq::Sorbet do
  it "has a version number" do
    expect(Sidekiq::Sorbet::VERSION).not_to be_nil
  end

  describe "module inclusion" do
    it "automatically includes Sidekiq::Job" do
      expect(SimpleWorker.ancestors).to include(Sidekiq::Job)
    end

    it "extends ClassMethods" do
      expect(SimpleWorker).to respond_to(:run_async)
      expect(SimpleWorker).to respond_to(:run_sync)
      expect(SimpleWorker).to respond_to(:args_class)
    end

    it "includes InstanceMethods" do
      worker = SimpleWorker.new
      expect(worker).to respond_to(:perform)
      expect(worker).to respond_to(:run)
      expect(worker).to respond_to(:args)
    end
  end
end
