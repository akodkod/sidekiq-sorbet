# typed: false
# frozen_string_literal: true

module Sidekiq
  module Sorbet
    module RSpec
      # Custom RSpec matchers for validating Sidekiq::Sorbet worker argument types
      module Matchers
        # Matcher for validating a single argument definition
        #
        # @example
        #   expect(MyWorker).to have_arg(:user_id, Integer)
        #   expect(MyWorker).to have_arg(:notify, T::Boolean).with_default(false)
        class HaveArg
          def initialize(field_name, expected_type = nil)
            @field_name = field_name
            @expected_type = expected_type
            @expected_default = nil
            @check_default = false
          end

          # Chain to check for a specific default value
          #
          # @param default_value [Object] The expected default value
          # @return [HaveArg] self for chaining
          def with_default(default_value)
            @expected_default = default_value
            @check_default = true
            self
          end

          def matches?(worker_class)
            @actual = worker_class
            props = fetch_props(worker_class)

            return false unless field_exists?(worker_class, props)
            return false unless type_matches?(worker_class, props[@field_name])
            return false unless default_matches?(worker_class, props[@field_name])

            true
          end

          def failure_message
            @failure_message || "expected #{@actual} to have argument :#{@field_name}"
          end

          def failure_message_when_negated
            "expected #{@actual}::Args not to have argument :#{@field_name}"
          end

          def description
            desc = "have argument :#{@field_name}"
            desc += " of type #{@expected_type}" if @expected_type
            desc += " with default #{@expected_default.inspect}" if @check_default
            desc
          end

          private

          def fetch_props(worker_class)
            args_class = worker_class.respond_to?(:args_class) ? worker_class.args_class : nil
            return {} unless args_class

            args_class.props
          rescue Sidekiq::Sorbet::ArgsNotDefinedError
            {}
          end

          def field_exists?(worker_class, props)
            return true if props.key?(@field_name)

            @failure_message = "expected #{worker_class}::Args to have argument :#{@field_name}, " \
                               "but it was not defined. " \
                               "Defined arguments: #{props.keys.map { |k| ":#{k}" }.join(', ')}"
            false
          end

          def type_matches?(worker_class, prop_info)
            return true unless @expected_type

            actual_type = prop_info[:type_object]
            return true if types_equal?(actual_type, @expected_type)

            @failure_message = "expected #{worker_class}::Args argument :#{@field_name} " \
                               "to be #{@expected_type}, but was #{actual_type}"
            false
          end

          def default_matches?(worker_class, prop_info)
            return true unless @check_default

            unless prop_info.key?(:default)
              @failure_message = "expected #{worker_class}::Args argument :#{@field_name} " \
                                 "to have a default value, but it was required"
              return false
            end

            actual_default = prop_info[:default]
            actual_default_value = actual_default.is_a?(Proc) ? actual_default.call : actual_default
            return true if actual_default_value == @expected_default

            @failure_message = "expected #{worker_class}::Args argument :#{@field_name} " \
                               "to have default value #{@expected_default.inspect}, " \
                               "but was #{actual_default_value.inspect}"
            false
          end

          def types_equal?(actual, expected)
            return true if actual == expected
            return true if actual.to_s == expected.to_s

            # Handle wrapped types (e.g., T.nilable returns a wrapper)
            return true if actual.respond_to?(:raw_type) && actual.raw_type == expected

            false
          end
        end

        # Matcher for validating multiple arguments at once
        #
        # @example
        #   expect(MyWorker).to have_args(user_id: Integer, name: String)
        #   expect(MyWorker).to have_args(:user_id, Integer).and_arg(:name, String)
        class HaveArgs
          def initialize(args_hash_or_field = nil, expected_type = nil)
            @args_to_check = []

            if args_hash_or_field.is_a?(Hash)
              args_hash_or_field.each do |field_name, type|
                @args_to_check << [field_name, type]
              end
            elsif args_hash_or_field.is_a?(Symbol)
              @args_to_check << [args_hash_or_field, expected_type]
            end
          end

          # Chain to add additional argument checks
          #
          # @param field_name [Symbol] The argument name
          # @param expected_type [Class] The expected type
          # @return [HaveArgs] self for chaining
          def and_arg(field_name, expected_type)
            @args_to_check << [field_name, expected_type]
            self
          end

          def matches?(worker_class)
            @actual = worker_class

            @args_to_check.each do |field_name, expected_type|
              matcher = HaveArg.new(field_name, expected_type)
              unless matcher.matches?(worker_class)
                @failure_message = matcher.failure_message
                return false
              end
            end

            true
          end

          def failure_message
            @failure_message || "expected #{@actual} to have the specified arguments"
          end

          def failure_message_when_negated
            "expected #{@actual}::Args not to have the specified arguments"
          end

          def description
            args_desc = @args_to_check.map { |name, type| "#{name}: #{type}" }.join(", ")
            "have arguments: #{args_desc}"
          end
        end

        # Matcher for validating that a worker accepts specific arguments
        #
        # @example
        #   expect(MyWorker).to accept_args(user_id: 123)
        #   expect(MyWorker).to accept_args(user_id: 123, name: "Alice")
        class AcceptArgs
          def initialize(args)
            @args = args
          end

          def matches?(worker_class)
            @actual = worker_class

            worker_class.send(:build_args, **@args)
            true
          rescue Sidekiq::Sorbet::InvalidArgsError,
                 Sidekiq::Sorbet::ArgsNotDefinedError,
                 ArgumentError,
                 TypeError => e
            @raised_error = e
            false
          end

          def failure_message
            "expected #{@actual} to accept arguments #{@args.inspect}, " \
              "but it raised #{@raised_error.class}: #{@raised_error.message}"
          end

          def failure_message_when_negated
            "expected #{@actual} not to accept arguments #{@args.inspect}, but it did"
          end

          def description
            "accept arguments #{@args.inspect}"
          end
        end

        # Matcher for validating that a worker rejects invalid arguments
        #
        # @example
        #   expect(MyWorker).to reject_args(user_id: "not an integer")
        #   expect(MyWorker).to reject_args(user_id: "bad").with_error(Sidekiq::Sorbet::InvalidArgsError)
        #   expect(MyWorker).to reject_args(user_id: "bad").with_error(Sidekiq::Sorbet::InvalidArgsError, /Invalid/)
        class RejectArgs
          def initialize(args)
            @args = args
            @expected_error = nil
            @expected_message = nil
          end

          # Chain to specify the expected error class and optional message pattern
          #
          # @param error_class [Class] The expected error class
          # @param message_pattern [Regexp, nil] Optional pattern to match error message
          # @return [RejectArgs] self for chaining
          def with_error(error_class, message_pattern = nil)
            @expected_error = error_class
            @expected_message = message_pattern
            self
          end

          def matches?(worker_class)
            @actual = worker_class

            begin
              worker_class.send(:build_args, **@args)
              @accepted = true
              false
            rescue StandardError => e
              @raised_error = e

              return false if @expected_error && !e.is_a?(@expected_error)

              return false if @expected_message && @raised_error.message !~ @expected_message

              true
            end
          end

          def failure_message
            if @accepted
              "expected #{@actual} to reject arguments #{@args.inspect}, but it accepted them"
            elsif @expected_error && @raised_error && !@raised_error.is_a?(@expected_error)
              "expected #{@actual} to raise #{@expected_error}, but raised #{@raised_error.class}"
            elsif @expected_message && @raised_error
              "expected error message to match #{@expected_message.inspect}, " \
                "but was #{@raised_error.message.inspect}"
            else
              "unexpected state in reject_args matcher"
            end
          end

          def failure_message_when_negated
            "expected #{@actual} not to reject arguments #{@args.inspect}, " \
              "but it raised #{@raised_error.class}"
          end

          def description
            desc = "reject arguments #{@args.inspect}"
            desc += " with #{@expected_error}" if @expected_error
            desc += " matching #{@expected_message.inspect}" if @expected_message
            desc
          end
        end

        # DSL methods to create matcher instances

        # Validates that a worker has a specific argument defined
        #
        # @param field_name [Symbol] The argument name
        # @param expected_type [Class, nil] The expected type (optional)
        # @return [HaveArg] The matcher instance
        def have_arg(field_name, expected_type = nil)
          HaveArg.new(field_name, expected_type)
        end

        # Validates that a worker has specific arguments defined
        #
        # @overload have_args(args_hash)
        #   @param args_hash [Hash<Symbol, Class>] Arguments with their types
        # @overload have_args(field_name, expected_type)
        #   @param field_name [Symbol] The argument name
        #   @param expected_type [Class] The expected type
        # @return [HaveArgs] The matcher instance
        def have_args(args_hash_or_field = nil, expected_type = nil)
          HaveArgs.new(args_hash_or_field, expected_type)
        end

        # Validates that a worker accepts specific arguments
        #
        # @param args [Hash] The arguments to test
        # @return [AcceptArgs] The matcher instance
        def accept_args(args)
          AcceptArgs.new(args)
        end

        # Validates that a worker rejects specific arguments
        #
        # @param args [Hash] The arguments to test
        # @return [RejectArgs] The matcher instance
        def reject_args(args)
          RejectArgs.new(args)
        end
      end
    end
  end
end
