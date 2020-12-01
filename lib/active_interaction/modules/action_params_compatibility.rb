# coding: utf-8
# frozen_string_literal: true

module ActiveInteraction
  # Convert ActionController::Params to hash
  #
  # @private
  module ActionParamsCompatibility
    class << self
      # We want to allow both `Hash` objects and `ActionController::Parameters`
      # objects. In Rails < 5, parameters are a subclass of hash and calling
      # `#symbolize_keys` returns the entire hash, not just permitted values. In
      # Rails >= 5, parameters are not a subclass of hash but calling
      # `#to_unsafe_h` returns the entire hash.
      def cast_to_hash(params)
        return params if params.is_a? Hash

        if action_params_klass && params.is_a?(action_params_klass)
          return params.to_unsafe_h
        end

        params
      end

      def action_params_klass
        @action_params_klass ||= 'ActionController::Parameters'.safe_constantize
      end
    end
  end
end
