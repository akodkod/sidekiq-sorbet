# frozen_string_literal: true

RSpec.describe "Sidekiq::Sorbet integration with Sidekiq" do
  it "works with Sidekiq testing mode" do
    # Ensure we're in testing mode
    expect(Sidekiq::Testing).to be_inline
    SimpleWorker.run_async(value: 3)
    # In inline mode, job executed immediately
  end

  it "enqueues with serialized arguments" do
    # Test that the job gets properly queued with correct args
    Sidekiq::Testing.fake! do
      SimpleWorker.run_async(value: 5)

      expect(SimpleWorker.jobs.size).to eq(1)
      job = SimpleWorker.jobs.first
      expect(job["args"]).to be_an(Array)
      expect(job["args"].first).to be_a(Hash)
      expect(job["args"].first["value"]).to eq(5)

      SimpleWorker.clear
    end

    # Restore inline mode
    Sidekiq::Testing.inline!
  end
end
