# frozen_string_literal: true
# typed: strict

return unless defined?(Tapioca)

module Tapioca
  module Dsl
    module Compilers
      # Generates RBI files for Sidekiq::Sorbet workers
      #
      # This compiler generates:
      # - Instance methods for direct argument access (value, attachment_id, etc.)
      # - Class methods run_async and run_sync with proper keyword argument signatures
      #
      # @example Worker with Args
      #   class MyWorker
      #     include Sidekiq::Sorbet
      #
      #     class Args < T::Struct
      #       const :user_id, Integer
      #       const :notify, T::Boolean, default: false
      #     end
      #
      #     def run
      #       user_id  # Direct access
      #       notify
      #     end
      #   end
      #
      #   # Generates:
      #   # sig { returns(Integer) }
      #   # def user_id; end
      #   #
      #   # sig { returns(T::Boolean) }
      #   # def notify; end
      #   #
      #   # sig { params(user_id: Integer, notify: T::Boolean).returns(String) }
      #   # def self.run_async(user_id:, notify: false); end
      #   #
      #   # sig { params(user_id: Integer, notify: T::Boolean).returns(T.untyped) }
      #   # def self.run_sync(user_id:, notify: false); end
      class SidekiqSorbet < Compiler
        extend T::Sig

        sig { override.void }
        def decorate
          root.create_path(constant) do |klass|
            generate_argument_accessors(klass) if args_class
            generate_run_async_method(klass)
            generate_run_sync_method(klass)
          end
        end

        sig { override.returns(T::Enumerable[Module]) }
        def self.gather_constants
          all_classes.select do |c|
            c.is_a?(Class) && c.included_modules.include?(::Sidekiq::Sorbet)
          end
        end

        private

        sig { returns(T.nilable(T.class_of(T::Struct))) }
        def args_class
          constant.const_get(:Args, false)
        rescue NameError
          nil
        end

        sig { params(klass: RBI::Scope).void }
        def generate_argument_accessors(klass)
          return unless args_class

          args_class.props.each do |field_name, prop_info|
            type = prop_info[:type_object].to_s

            klass.create_method(
              field_name.to_s,
              return_type: type,
            )
          end
        end

        sig { params(klass: RBI::Scope).void }
        def generate_run_async_method(klass)
          klass.create_method(
            "run_async",
            parameters: build_params_signature,
            return_type: "String",
            class_method: true,
          )
        end

        sig { params(klass: RBI::Scope).void }
        def generate_run_sync_method(klass)
          klass.create_method(
            "run_sync",
            parameters: build_params_signature,
            return_type: "T.untyped",
            class_method: true,
          )
        end

        sig { returns(T::Array[RBI::TypedParam]) }
        def build_params_signature
          return [] unless args_class

          args_class.props.map do |field_name, prop_info|
            type = prop_info[:type_object].to_s
            has_default = prop_info.key?(:default)

            param = if has_default
                      RBI::KwOptParam.new(field_name.to_s, "T.unsafe(nil)")
                    else
                      RBI::KwParam.new(field_name.to_s)
                    end

            RBI::TypedParam.new(param: param, type: type)
          end
        end
      end
    end
  end
end
