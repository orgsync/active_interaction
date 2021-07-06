# frozen_string_literal: true

module ActiveInteraction
  # @abstract Subclass and override {#execute} to implement a custom
  #   ActiveInteraction::Base class.
  #
  # Provides interaction functionality. Subclass this to create an interaction.
  #
  # @example
  #   class ExampleInteraction < ActiveInteraction::Base
  #     # Required
  #     boolean :a
  #
  #     # Optional
  #     boolean :b, default: false
  #
  #     def execute
  #       a && b
  #     end
  #   end
  #
  #   outcome = ExampleInteraction.run(a: true)
  #   if outcome.valid?
  #     outcome.result
  #   else
  #     outcome.errors
  #   end
  class Base
    include ActiveModelable
    include ActiveRecordable
    include Runnable

    define_callbacks :type_check

    class << self
      include Hashable
      include Missable

      # @!method run(inputs = {})
      #   @note If the interaction inputs are valid and there are no runtime
      #     errors and execution completed successfully, {#valid?} will always
      #     return true.
      #
      #   Runs validations and if there are no errors it will call {#execute}.
      #
      #   @param (see ActiveInteraction::Inputs.process)
      #
      #   @return [Base]

      # @!method run!(inputs = {})
      #   Like {.run} except that it returns the value of {#execute} or raises
      #     an exception if there were any validation errors.
      #
      #   @param (see ActiveInteraction::Base.run)
      #
      #   @return (see ActiveInteraction::Runnable::ClassMethods#run!)
      #
      #   @raise (see ActiveInteraction::Runnable::ClassMethods#run!)

      # Get or set the description.
      #
      # @example
      #   core.desc
      #   # => nil
      #   core.desc('Description!')
      #   core.desc
      #   # => "Description!"
      #
      # @param desc [String, nil] What to set the description to.
      #
      # @return [String, nil] The description.
      def desc(desc = nil)
        if desc.nil?
          @_interaction_desc = nil unless instance_variable_defined?(:@_interaction_desc)
        else
          @_interaction_desc = desc
        end

        @_interaction_desc
      end

      # Enables strict inputs.
      #
      # Requires that provided inputs to the interactor explicitly match declared filters.
      #
      # @example
      #   strict_filters true
      #
      # @param strict [Boolean, nil] Enable strict inputs.
      #
      # @return [Boolean] Current strict input setting.
      def strict_inputs(strict = nil)
        if strict.nil?
          @_interactor_strict_inputs = false unless instance_variable_defined?(:@_interactor_strict_inputs)
        else
          @_interactor_strict_inputs = strict
        end

        @_interactor_strict_inputs
      end

      # Get all the filters defined on this interaction.
      #
      # @return [Hash{Symbol => Filter}]
      def filters
        # rubocop:disable Naming/MemoizedInstanceVariableName
        @_interaction_filters ||= {}
        # rubocop:enable Naming/MemoizedInstanceVariableName
      end

      # @private
      # rubocop:disable Style/MissingRespondToMissing
      def method_missing(*args, &block)
        super do |klass, names, options|
          raise InvalidFilterError, 'missing attribute name' if names.empty?

          names.each { |name| add_filter(klass, name, options, &block) }
        end
      end
      # rubocop:enable Style/MissingRespondToMissing

      private

      # @param klass [Class]
      # @param name [Symbol]
      # @param options [Hash]
      def add_filter(klass, name, options, &block)
        raise InvalidFilterError, %("#{name}" is a reserved name) if Inputs.reserved?(name)

        initialize_filter(klass.new(name, options, &block))
      end

      # Import filters from another interaction.
      #
      # @param klass [Class] The other interaction.
      # @param options [Hash]
      #
      # @option options [Array<Symbol>, nil] :only Import only these filters.
      # @option options [Array<Symbol>, nil] :except Import all filters except
      #   for these.
      #
      # @return (see .filters)
      #
      # @!visibility public
      def import_filters(klass, options = {})
        only = options[:only]
        except = options[:except]

        other_filters = klass.filters.dup
        other_filters.select! { |k, _| [*only].include?(k) } if only
        other_filters.reject! { |k, _| [*except].include?(k) } if except

        other_filters.each_value { |filter| initialize_filter(filter) }
      end

      # @param klass [Class]
      def inherited(klass)
        klass.instance_variable_set(:@_interaction_filters, filters.dup)

        super
      end

      # @param filter [Filter]
      def initialize_filter(filter)
        attribute = filter.name
        warn "WARNING: Redefining #{name}##{attribute} filter" if filters.key?(attribute)
        filters[attribute] = filter

        attr_accessor attribute

        eagerly_evaluate_default(filter)
      end

      # @param filter [Filter]
      def eagerly_evaluate_default(filter)
        default = filter.options[:default]
        filter.default if default && !default.is_a?(Proc)
      end
    end

    # @private
    def initialize(inputs = {})
      @_interaction_raw_inputs = inputs

      populate_filters_and_inputs(Inputs.process(inputs))
    end

    # @!method compose(other, inputs = {})
    #   Run another interaction and return its result. If the other interaction
    #     fails, halt execution.
    #
    #   @param other (see ActiveInteraction::Runnable#compose)
    #   @param inputs (see ActiveInteraction::Base#initialize)
    #
    #   @return (see ActiveInteraction::Base.run!)

    # @!method execute
    #   @abstract
    #
    #   Runs the business logic associated with the interaction. This method is
    #   only run when there are no validation errors. The return value is
    #   placed into {#result}.
    #
    #   @raise (see ActiveInteraction::Runnable#execute)

    # Returns the inputs provided to {.run} or {.run!} after being cast based
    #   on the filters in the class.
    #
    # @return [Hash{Symbol => Object}] All inputs passed to {.run} or {.run!}.
    def inputs
      @_interaction_inputs
    end

    # Returns `true` if the given key was in the hash passed to {.run}.
    # Otherwise returns `false`. Use this to figure out if an input was given,
    # even if it was `nil`. Keys within nested hash filter can also be checked
    # by passing them in series. Arrays can be checked in the same manor as
    # hashes by passing an index.
    #
    # @example
    #   class Example < ActiveInteraction::Base
    #     integer :x, default: nil
    #     def execute; given?(:x) end
    #   end
    #   Example.run!()        # => false
    #   Example.run!(x: nil)  # => true
    #   Example.run!(x: rand) # => true
    #
    # @example Nested checks
    #   class Example < ActiveInteraction::Base
    #     hash :x, default: {} do
    #       integer :y, default: nil
    #     end
    #     array :a, default: [] do
    #       integer
    #     end
    #     def execute; given?(:x, :y) || given?(:a, 2) end
    #   end
    #   Example.run!()               # => false
    #   Example.run!(x: nil)         # => false
    #   Example.run!(x: {})          # => false
    #   Example.run!(x: { y: nil })  # => true
    #   Example.run!(x: { y: rand }) # => true
    #   Example.run!(a: [1, 2])      # => false
    #   Example.run!(a: [1, 2, 3])   # => true
    #
    # @param input [#to_sym]
    #
    # @return [Boolean]
    #
    # @since 2.1.0
    # rubocop:disable all
    def given?(input, *rest)
      filter_level = self.class
      input_level = @_interaction_raw_inputs

      [input, *rest].each do |key_or_index|
        if key_or_index.is_a?(Symbol) || key_or_index.is_a?(String)
          key = key_or_index.to_sym
          key_to_s = key_or_index.to_s
          filter_level = filter_level.filters[key]

          break false if filter_level.nil? || input_level.nil?
          if filter_level.accepts_grouped_inputs?
            break false unless input_level.key?(key) || input_level.key?(key_to_s) || Inputs.keys_for_group?(input_level.keys, key)
          else
            break false unless input_level.key?(key) || input_level.key?(key_to_s)
          end

          input_level = input_level[key] || input_level[key_to_s]
        else
          index = key_or_index
          filter_level = filter_level.filters.first.last

          break false if filter_level.nil? || input_level.nil?
          break false unless index.between?(-input_level.size, input_level.size - 1)

          input_level = input_level[index]
        end
      end && true
    end
    # rubocop:enable all

    protected

    def run_validations!
      type_check

      super if errors.empty?
    end

    private

    def populate_filters_and_inputs(inputs)
      @_interaction_inputs = Inputs.new

      self.class.filters.each do |name, filter|
        value =
          begin
            filter.clean(inputs[name], self)
          rescue InvalidValueError, MissingValueError, NoDefaultError
            # #type_check will add errors if appropriate.
            # We'll get the original value for the error.
            inputs[name]
          end

        @_interaction_inputs[name] = value
        public_send("#{name}=", value)
      end

      strict_inputs_check(inputs)
      @_interaction_inputs.freeze
    end

    def strict_inputs_check(inputs)
      return unless self.class.strict_inputs
      return unless (unexpected_keys = inputs.keys - @_interaction_inputs.keys).any?

      raise InvalidInputsError, "unexpected inputs: #{unexpected_keys.join(', ')}."
    end

    def type_check
      run_callbacks(:type_check) do
        Validation.validate(self, self.class.filters, inputs).each do |attr, type, kwargs = {}|
          errors.add(attr, type, **kwargs)
        end
      end
    end
  end
end
