# frozen_string_literal: true

module ActiveInteraction
  # Top-level error class. All other errors subclass this.
  #
  # @return [Class]
  Error = Class.new(StandardError)

  # Raised if a constant name is invalid.
  #
  # @return [Class]
  InvalidNameError = Class.new(Error)

  # Raised if a converter is invalid.
  #
  # @return [Class]
  InvalidConverterError = Class.new(Error)

  # Raised if a default value is invalid.
  #
  # @return [Class]
  InvalidDefaultError = Class.new(Error)

  # Raised if a filter has an invalid definition.
  #
  # @return [Class]
  InvalidFilterError = Class.new(Error)

  # Raised if a supplied inputs contain unexpected inputs.
  #
  # @return [Class]
  InvalidInputsError = Class.new(Error)

  # Raised if an interaction is invalid.
  #
  # @return [Class]
  class InvalidInteractionError < Error
    attr_accessor :interaction
  end

  # Raised if a user-supplied value is invalid.
  #
  # @return [Class]
  InvalidValueError = Class.new(Error)

  # Raised if a filter cannot be found.
  #
  # @return [Class]
  MissingFilterError = Class.new(Error)

  # Raised if no value is given.
  #
  # @return [Class]
  MissingValueError = Class.new(Error)

  # Raised if there is no default value.
  #
  # @return [Class]
  NoDefaultError = Class.new(Error)

  # Raised if a user-supplied value to a nested hash input is invalid.
  #
  # @return [Class]
  class InvalidNestedValueError < InvalidValueError
    # @return [Symbol]
    attr_reader :filter_name

    # @return [Object]
    attr_reader :input_value

    # @param filter_name [Symbol]
    # @param input_value [Object]
    def initialize(filter_name, input_value)
      super("#{filter_name}: #{input_value.inspect}")

      @filter_name = filter_name
      @input_value = input_value
    end
  end

  # Used by {Runnable} to signal a failure when composing.
  #
  # @private
  class Interrupt < Error
    attr_reader :errors

    # @param errors [Runnable]
    def initialize(errors)
      super()

      @errors = errors
    end
  end
  private_constant :Interrupt

  # An extension that provides the ability to merge other errors into itself.
  class Errors < ActiveModel::Errors
    attr_accessor :backtrace

    # Merge other errors into this one.
    #
    # @param other [Errors]
    #
    # @return [Errors]
    def merge!(other)
      merge_details!(other)

      self
    end

    private

    def attribute?(attribute)
      @base.respond_to?(attribute)
    end

    def detailed_error?(detail)
      detail[:error].is_a?(Symbol)
    end

    def merge_message!(attribute, message)
      unless attribute?(attribute)
        message = full_message(attribute, message)
        attribute = :base
      end
      add(attribute, message) unless added?(attribute, message)
    end

    def merge_details!(other)
      other.messages.each do |attribute, messages|
        messages.zip(other.details[attribute]) do |message, detail|
          if detailed_error?(detail)
            merge_detail!(attribute, detail, message)
          else
            merge_message!(attribute, message)
          end
        end
      end
    end

    def merge_detail!(attribute, detail, message)
      if attribute?(attribute) || attribute == :base
        options = detail.dup
        error = options.delete(:error)

        add(attribute, error, **options.merge(message: message)) unless added?(attribute, error, **options)
      else
        merge_message!(attribute, message)
      end
    end
  end
end
