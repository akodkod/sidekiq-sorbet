# typed: true
# frozen_string_literal: true

require "sorbet-runtime"
require "sorbet-schema"
require_relative "sorbet/version"
require_relative "sorbet/errors"
require_relative "sorbet/class_methods"
require_relative "sorbet/instance_methods"

# Load Tapioca DSL compiler if Tapioca is available
begin
  require "tapioca/dsl"
  require_relative "../tapioca/dsl/compilers/sidekiq_sorbet"
rescue LoadError
  # Tapioca not available, skip compiler
end

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
