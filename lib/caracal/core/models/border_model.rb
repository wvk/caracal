require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models

      # This class handles block options passed to the page margins
      # method.
      class BorderModel < BaseModel
        ATTRS = [:color, :theme_color, :line, :size, :spacing].freeze
        TYPES = [:top, :bottom, :left, :right, :horizontal, :vertical].freeze

        use_prefix :border

        has_string_attribute :color, default: 'auto'

        has_model_attribute :theme_color,
            model: Caracal::Core::Models::ThemeColorModel

        has_symbol_attribute :line, default: :single
        has_symbol_attribute :type

        has_integer_attribute :size, default: 0 # 1/8 points
        has_integer_attribute :spacing          # points, rendered as 0 when nil

        # readers fall back to the (subclass) defaults, so that unset
        # attributes can be told apart from set ones (see #given?)
        ATTRS.each do |attr|
          define_method "border_#{attr}" do
            v = instance_variable_get "@border_#{attr}"
            v.nil? ? self.class.const_get("DEFAULT_BORDER_#{attr.upcase}") : v
          end
        end


        #-------------------------------------------------------------
        # Class Methods
        #-------------------------------------------------------------

        def self.formatted_type(type)
          {
            horizontal: 'insideH',
            vertical:   'insideV',
            top:        'top',
            bottom:     'bottom',
            left:       'left',
            right:      'right'
          }[type.to_s.to_sym]
        end

        #=============== GETTERS ==============================

        def given?(attr)
          not instance_variable_get("@border_#{attr}").nil?
        end

        def formatted_type
          self.class.formatted_type(border_type) || ''
        end

        def total_size
          if undefined?
            0
          else
            border_size + (2 * border_spacing.to_i)
          end
        end

        #=============== VALIDATION ==============================

        def valid?
          dims = [:size, :spacing]
          (undefined? or dims.all? {|d| validate_size d, at_least: 0, allow_nil: true }) and
              validate_inclusion :type, within: TYPES, allow_nil: true
        end

        def undefined?
          self.border_line == :none or self.border_line.nil?
        end

        private

        def option_keys
          ATTRS + [:type]
        end

      end
    end
  end
end
