# typed: false
# frozen_string_literal: true

require "sorbet-runtime"

module Sidekiq
  module Sorbet
    # Class methods added to workers that include Sidekiq::Sorbet
    module ClassMethods
      extend T::Sig

      # Enqueues a job asynchronously with validated arguments
      #
      # @param kwargs [Hash] Arguments matching the Args T::Struct (or empty if no Args)
      # @return [String] Sidekiq job ID
      # @raise [InvalidArgsError] if arguments fail validation
      # @raise [SerializationError] if serialization fails
      sig { params(kwargs: T.untyped).returns(String) }
      def run_async(**kwargs)
        args_instance = build_args(**kwargs)
        serialized = serialize_args(args_instance)
        perform_async(serialized)
      end

      # Executes a job synchronously with validated arguments
      #
      # @param kwargs [Hash] Arguments matching the Args T::Struct (or empty if no Args)
      # @return [Object] Result of the run method
      # @raise [InvalidArgsError] if arguments fail validation
      sig { params(kwargs: T.untyped).returns(T.untyped) }
      def run_sync(**kwargs)
        args_instance = build_args(**kwargs)
        worker = new
        worker.instance_variable_set(:@args, args_instance)
        worker.define_arg_accessors if args_instance
        worker.run
      rescue InvalidArgsError, ArgsNotDefinedError, SerializationError
        raise
      rescue StandardError => e
        raise Error,
              "Error in #{name}#run: #{e.message}\n#{e.backtrace&.join("\n")}"
      end

      # Returns the Args class for this worker, or nil if not defined
      #
      # @return [Class, nil] The Args T::Struct class or nil
      sig { returns(T.nilable(T.class_of(T::Struct))) }
      def args_class
        return @args_class if defined?(@args_class)

        @args_class = T.let(
          begin
            klass = const_defined?(:Args, false) ? const_get(:Args) : nil
            validate_args_class!(klass) if klass
            klass
          end,
          T.nilable(T.class_of(T::Struct)),
        )
      end

      private

      # Validates that the Args class is a T::Struct
      #
      # @param klass [Class] The class to validate
      # @return [Class] The validated class
      # @raise [ArgsNotDefinedError] if invalid
      sig { params(klass: T.untyped).returns(T.class_of(T::Struct)) }
      def validate_args_class!(klass)
        unless klass < T::Struct
          raise ArgsNotDefinedError,
                "#{name}::Args must inherit from T::Struct, got #{klass.class}"
        end

        klass
      end

      # Builds and validates Args instance (or returns nil if no Args class)
      #
      # @param kwargs [Hash] Arguments to pass to Args.new
      # @return [T::Struct, nil] Validated Args instance or nil
      # @raise [InvalidArgsError] if validation fails
      sig { params(kwargs: T.untyped).returns(T.nilable(T::Struct)) }
      def build_args(**kwargs)
        return nil unless args_class

        if kwargs.empty?
          # No args provided - create empty Args if possible
          args_class.new
        else
          args_class.new(**kwargs)
        end
      rescue ArgumentError, TypeError => e
        raise InvalidArgsError,
              "Invalid arguments for #{name}: #{e.message}"
      end

      # Serializes Args instance to JSON-compatible hash
      #
      # @param args_instance [T::Struct, nil] The Args instance or nil
      # @return [Hash] Serialized hash with string keys (empty if nil)
      # @raise [SerializationError] if serialization fails
      sig { params(args_instance: T.nilable(T::Struct)).returns(T::Hash[String, T.untyped]) }
      def serialize_args(args_instance)
        return {} unless args_instance

        args_instance.serialize
      rescue StandardError => e
        raise SerializationError,
              "Failed to serialize args for #{name}: #{e.message}"
      end
    end
  end
end
