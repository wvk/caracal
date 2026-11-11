require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class handles block options passed to the margins
      # method.
      #
      class MarginModel < BaseModel
        use_prefix :margin

        has_integer_attribute :top
        has_integer_attribute :bottom
        has_integer_attribute :left
        has_integer_attribute :right

        # initialization
        def initialize(options={}, &block)
          @margin_top    = DEFAULT_MARGIN_TOP
          @margin_bottom = DEFAULT_MARGIN_BOTTOM
          @margin_left   = DEFAULT_MARGIN_LEFT
          @margin_right  = DEFAULT_MARGIN_RIGHT

          super options, &block
        end

        #=============== VALIDATION ==============================

        def valid?
          [:bottom, :left, :right, :top].all? {|a| validate_size a, at_least: 0, allow_nil: true }
        end

        private

        def option_keys
          [:top, :bottom, :left, :right]
        end

      end
    end
  end
end
