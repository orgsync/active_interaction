# coding: utf-8
# frozen_string_literal: true

module ActiveInteraction
  class Base
    # @!method self.hash(*attributes, options = {}, &block)
    #   Creates accessors for the attributes and ensures that values passed to
    #     the attributes are Hashes.
    #
    #   @!macro filter_method_params
    #   @param block [Proc] filter methods to apply for select keys
    #   @option options [Boolean] :strip (true) remove unknown keys
    #
    #   @example
    #     hash :order
    #   @example
    #     hash :order do
    #       object :item
    #       integer :quantity, default: 1
    #     end
  end

  # @private
  class HashFilter < Filter
    include Missable

    register :hash

    # rubocop:disable Metrics/MethodLength
    def cast(value, context)
      value = ActionParamsCompatibility.cast_to_hash(value)
      case value
      when Hash
        value = value.with_indifferent_access
        initial = strip? ? ActiveSupport::HashWithIndifferentAccess.new : value

        filters.each_with_object(initial) do |(name, filter), h|
          clean_value(h, name.to_s, filter, value, context)
        end
      else
        super
      end
    end

    def method_missing(*args, &block) # rubocop:disable Style/MethodMissing
      super(*args) do |klass, names, options|
        raise InvalidFilterError, 'missing attribute name' if names.empty?

        names.each do |name|
          filters[name] = klass.new(name, options, &block)
        end
      end
    end

    private

    def clean_value(h, name, filter, value, context)
      h[name] = filter.clean(value[name], context)
    rescue InvalidValueError, MissingValueError
      raise InvalidNestedValueError.new(name, value[name])
    end

    def raw_default(*)
      value = super

      if value.is_a?(Hash) && !value.empty?
        raise InvalidDefaultError, "#{name}: #{value.inspect}"
      end

      value
    end

    # @return [Boolean]
    def strip?
      options.fetch(:strip, true)
    end
  end
end
