# typed: false
# frozen_string_literal: true

require "sorbet-runtime"

module Sidekiq
  module Sorbet
    # Instance methods added to workers that include Sidekiq::Sorbet
    module InstanceMethods
      extend T::Sig

      # Sidekiq calls this method when executing the job
      # We deserialize the args and delegate to the user's run method
      #
      # @param serialized_hash [Hash] Serialized arguments from Sidekiq
      # @return [Object] Result of the run method
      # @raise [SerializationError] if deserialization fails
      sig { params(serialized_hash: T::Hash[String, T.untyped]).returns(T.untyped) }
      def perform(serialized_hash)
        @args = T.let(
          deserialize_args(serialized_hash),
          T.nilable(T::Struct),
        )
        define_arg_accessors if @args
        run
      rescue SerializationError
        raise
      rescue StandardError => e
        raise Error,
              "Error in #{self.class.name}#run: #{e.message}\n#{e.backtrace&.join("\n")}"
      end

      # Accessor for typed arguments (optional, for backward compatibility)
      #
      # @return [T::Struct, nil] The Args instance or nil
      sig { returns(T.nilable(T::Struct)) }
      def args
        @args
      end

      # Define getter methods for each field in the Args struct
      # This allows direct access like `attachment_id` instead of `args.attachment_id`
      #
      # @return [void]
      sig { void }
      def define_arg_accessors
        return unless @args

        @args.class.props.each_key do |field_name|
          # Skip if method already defined (avoid overriding user methods)
          next if respond_to?(field_name, true) && !@args.respond_to?(field_name)

          # Define a method to access the field
          define_singleton_method(field_name) do
            @args.public_send(field_name)
          end
        end
      end

      # Users implement this method in their worker
      #
      # @return [Object] Whatever the worker returns
      # @raise [NotImplementedError] if not overridden
      sig { returns(T.untyped) }
      def run
        raise NotImplementedError,
              "#{self.class.name} must implement #run method"
      end

      private

      # Deserializes hash back into Args T::Struct
      #
      # @param serialized_hash [Hash] Hash with string keys from Sidekiq
      # @return [T::Struct, nil] Deserialized Args instance or nil
      # @raise [SerializationError] if deserialization fails
      sig { params(serialized_hash: T::Hash[String, T.untyped]).returns(T.nilable(T::Struct)) }
      def deserialize_args(serialized_hash)
        args_klass = self.class.args_class
        return nil unless args_klass

        args_klass.from_hash(serialized_hash)
      rescue StandardError => e
        raise SerializationError,
              "Failed to deserialize args for #{self.class.name}: #{e.message}"
      end
    end
  end
end
