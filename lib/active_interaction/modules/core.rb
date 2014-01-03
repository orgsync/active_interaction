# coding: utf-8

begin
  require 'active_record'
rescue LoadError
  # ActiveRecord is an optional dependency.
end

module ActiveInteraction
  # Functionality common between {Base}.
  #
  # @see Base
  module Core
    # Get or set the description.
    #
    # @example
    #   core.desc
    #   # => nil
    #   core.desc('descriptive!')
    #   core.desc
    #   # => "descriptive!"
    #
    # @param desc [String, nil] what to set the description to
    #
    # @return [String, nil] the description
    #
    # @since 0.8.0
    def desc(desc = nil)
      if desc.nil?
        unless instance_variable_defined?(:@_interaction_desc)
          @_interaction_desc = nil
        end
      else
        @_interaction_desc = desc
      end

      @_interaction_desc
    end

    # Runs validations and if there are no errors it will call {#execute}.
    #
    # @param (see #initialize)
    #
    # @return [ActiveInteraction::Base] An instance of the class `run` is
    #   called on.
    def run(*args)
      new(*args).tap do |interaction|
        next if interaction.invalid?

        result = transaction do
          begin
            interaction.execute
          rescue Interrupt
            # Inner interaction failed. #compose handles merging errors.
          end
        end

        finish(interaction, result)
      end
    end

    # Like {Base.run} except that it returns the value of {Base#execute} or
    #   raises an exception if there were any validation errors.
    #
    # @param (see Base.run)
    #
    # @return [Object] the return value of {Base#execute}
    #
    # @raise [InvalidInteractionError] if the outcome is invalid
    def run!(*args)
      outcome = run(*args)

      if outcome.valid?
        outcome.result
      else
        fail InvalidInteractionError, outcome.errors.full_messages.join(', ')
      end
    end

    private

    def finish(interaction, result)
      if interaction.errors.empty?
        interaction.instance_variable_set(
          :@_interaction_result, result)
      else
        interaction.instance_variable_set(
          :@_interaction_runtime_errors, interaction.errors.dup)
      end
    end

    def transaction(*args)
      return unless block_given?

      if defined?(ActiveRecord)
        ::ActiveRecord::Base.transaction(*args) { yield }
      else
        yield
      end
    end
  end
end
