# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require_relative "sorbet/version"
require_relative "sorbet/errors"
require_relative "sorbet/class_methods"
require_relative "sorbet/instance_methods"

module Sidekiq
  module Sorbet
    extend T::Sig

    # Hook called when Sidekiq::Sorbet is included in a worker
    # Automatically includes Sidekiq::Job if needed and wires up our modules
    #
    # @param base [Class] The worker class including this module
    sig { params(base: T.untyped).void }
    def self.included(base)
      base.include(Sidekiq::Job) unless base.ancestors.include?(Sidekiq::Job)
      base.extend(ClassMethods)
      base.include(InstanceMethods)
    end
  end
end
