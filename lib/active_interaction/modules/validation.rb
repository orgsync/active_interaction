# frozen_string_literal: true

module ActiveInteraction
  # Validates inputs using filters.
  #
  # @private
  module Validation
    class << self
      # @param context [Base]
      # @param filters [Hash{Symbol => Filter}]
      # @param inputs [Hash{Symbol => Object}]
      def validate(context, filters, inputs)
        filters.each_with_object([]) do |(name, filter), errors|
          filter.clean(inputs[name], context)
        rescue NoDefaultError
          nil
        rescue InvalidNestedValueError,
               InvalidValueError,
               MissingValueError => e
          errors << error_args(filter, e)
        end
      end

      private

      def error_args(filter, error)
        case error
        when InvalidNestedValueError
          [nested_error_key(filter, error),
           nested_value_error(error.input_value.inspect)]
        when InvalidValueError
          [filter.name, :invalid_type, { type: type(filter) }]
        when MissingValueError
          [filter.name, :missing]
        end
      end

      # @param filter [Filter]
      def type(filter)
        I18n.translate("#{Base.i18n_scope}.types.#{filter.class.slug}")
      end

      # @param value [String]
      def nested_value_error(value)
        I18n.translate(
          :invalid_nested,
          scope: [Base.i18n_scope, :errors, :messages],
          value: value
        )
      end

      # @param filter [Filter]
      # @param error [InvalidNestedValueError]
      def nested_error_key(filter, error)
        suffix = "[#{error.nesting_index}]" if error.nesting_index
        "#{filter.name}#{suffix}.#{error.filter_name}"
      end
    end
  end
end
