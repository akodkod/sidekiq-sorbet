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

      # Enqueues a job to be performed at a specific time with validated arguments
      #
      # @param time [Time, Numeric] When to perform the job (timestamp or Time object)
      # @param kwargs [Hash] Arguments matching the Args T::Struct (or empty if no Args)
      # @return [String] Sidekiq job ID
      # @raise [InvalidArgsError] if arguments fail validation
      # @raise [SerializationError] if serialization fails
      sig { params(time: T.any(Time, Numeric), kwargs: T.untyped).returns(String) }
      def run_at(time, **kwargs)
        args_instance = build_args(**kwargs)
        serialized = serialize_args(args_instance)
        perform_at(time, serialized)
      end

      # Enqueues a job to be performed after a delay with validated arguments
      #
      # @param interval [Numeric] How long to wait before performing (in seconds)
      # @param kwargs [Hash] Arguments matching the Args T::Struct (or empty if no Args)
      # @return [String] Sidekiq job ID
      # @raise [InvalidArgsError] if arguments fail validation
      # @raise [SerializationError] if serialization fails
      sig { params(interval: Numeric, kwargs: T.untyped).returns(String) }
      def run_in(interval, **kwargs)
        args_instance = build_args(**kwargs)
        serialized = serialize_args(args_instance)
        perform_in(interval, serialized)
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

      # Serializes Args instance to JSON-compatible hash using sorbet-schema
      #
      # @param args_instance [T::Struct, nil] The Args instance or nil
      # @return [Hash] Serialized hash with string keys (empty if nil)
      # @raise [SerializationError] if serialization fails
      sig { params(args_instance: T.nilable(T::Struct)).returns(T::Hash[String, T.untyped]) }
      def serialize_args(args_instance)
        return {} unless args_instance

        serializer = Typed::HashSerializer.new(
          schema: args_instance.class.schema,
          should_serialize_values: true,
        )
        result = serializer.serialize(args_instance)

        if result.success?
          # Convert to string keys for Sidekiq strict args validation
          deep_stringify_keys(result.payload)
        else
          raise SerializationError,
                "Failed to serialize args for #{name}: #{result.error.message}"
        end
      rescue SerializationError
        raise
      rescue StandardError => e
        raise SerializationError,
              "Failed to serialize args for #{name}: #{e.message}"
      end

      # Recursively converts all hash keys to strings for Sidekiq compatibility
      sig { params(obj: T.untyped).returns(T.untyped) }
      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
        when Array
          obj.map { |v| deep_stringify_keys(v) }
        else
          obj
        end
      end
    end
  end
end
