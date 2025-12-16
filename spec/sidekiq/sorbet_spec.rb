# frozen_string_literal: true

RSpec.describe Sidekiq::Sorbet do
  it "has a version number" do
    expect(Sidekiq::Sorbet::VERSION).not_to be_nil
  end
end
