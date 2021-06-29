# frozen_string_literal: true

module ActiveInteraction
  class Base # rubocop:disable Lint/EmptyClass
    # @!method self.array(*attributes, options = {}, &block)
    #   Creates accessors for the attributes and ensures that values passed to
    #     the attributes are Arrays.
    #
    #   @!macro filter_method_params
    #   @param block [Proc] filter method to apply to each element
    #
    #   @example
    #     array :ids
    #   @example
    #     array :ids do
    #       integer
    #     end
    #   @example
    #     array :ids do
    #       integer default: nil
    #     end
  end

  # @private
  class ArrayFilter < Filter
    include Missable

    # The array starts with the class override key and then contains any
    # additional options which halt explicit setting of the class.
    FILTER_NAME_OR_OPTION = {
      'ActiveInteraction::ObjectFilter' => [:class].freeze,
      'ActiveInteraction::RecordFilter' => [:class].freeze,
      'ActiveInteraction::InterfaceFilter' => %i[from methods].freeze
    }.freeze
    private_constant :FILTER_NAME_OR_OPTION

    register :array

    private

    def klasses
      %w[
        ActiveRecord::Relation
        ActiveRecord::Associations::CollectionProxy
      ].each_with_object([Array]) do |name, result|
        next unless (klass = name.safe_constantize)

        result.push(klass)
      end
    end

    def matches?(value)
      klasses.any? { |klass| value.is_a?(klass) }
    rescue NoMethodError # BasicObject
      false
    end

    def adjust_output(value, context)
      return value if filters.empty?

      filter = filters.values.first
      value.map.with_index do |e, i|
        with_nested_error_handling(i) { filter.clean(e, context) }
      end
    end

    def convert(value)
      if value.respond_to?(:to_ary)
        value.to_ary
      else
        super
      end
    rescue NoMethodError # BasicObject
      super
    end

    def add_option_in_place_of_name(klass, options)
      if (keys = FILTER_NAME_OR_OPTION[klass.to_s]) && (keys && options.keys).empty?
        options.merge(
          "#{keys.first}": name.to_s.singularize.camelize.to_sym
        )
      else
        options
      end
    end

    # rubocop:disable Style/MissingRespondToMissing
    def method_missing(*, &block)
      super do |klass, names, options|
        options = add_option_in_place_of_name(klass, options)

        filter = klass.new(names.first || '', options, &block)

        filters[filters.size.to_s.to_sym] = filter

        validate!(filter, names)
      end
    end
    # rubocop:enable Style/MissingRespondToMissing

    def with_nested_error_handling(index)
      yield
    rescue InvalidNestedValueError => e
      e.nesting_index = index
      raise e
    end

    # @param filter [Filter]
    # @param names [Array<Symbol>]
    #
    # @raise [InvalidFilterError]
    def validate!(filter, names)
      raise InvalidFilterError, 'multiple filters in array block' if filters.size > 1

      raise InvalidFilterError, 'attribute names in array block' unless names.empty?

      raise InvalidDefaultError, 'default values in array block' if filter.default?

      nil
    end
  end
end
