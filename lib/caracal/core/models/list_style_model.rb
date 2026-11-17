module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # list style data.

      class ListStyleModel < BaseModel
        use_prefix :style

        has_integer_attribute :left,    default: 720 # in twips
        has_integer_attribute :indent,  default: 360 # in twips
        has_integer_attribute :start,   default: 1
        has_integer_attribute :restart, default: 1
        has_integer_attribute :level

        has_symbol_attribute :align, default: :left
        has_symbol_attribute :type

        has_string_attribute :format
        has_string_attribute :value

        #-------------------------------------------------------------
        # Configuration
        #-------------------------------------------------------------

        # constants
        const_set :TYPE_MAP, {ordered: 1, unordered: 2}

        def initialize(options={}, &block)
          @style_align   = DEFAULT_STYLE_ALIGN
          @style_left    = DEFAULT_STYLE_LEFT
          @style_indent  = DEFAULT_STYLE_INDENT
          @style_start   = DEFAULT_STYLE_START
          @style_restart = DEFAULT_STYLE_RESTART

          super options, &block
        end

        def self.formatted_type(type)
          TYPE_MAP.fetch(type.to_s.to_sym)
        end

        #=============== GETTERS ==============================

        def formatted_type
          self.class.formatted_type(style_type)
        end

        #=============== STATE ================================

        def matches?(type, level)
          style_type == type.to_s.to_sym and style_level == level.to_i
        end

        #=============== VALIDATION ===========================

        def valid?
          [:type, :level, :format, :value].all? {|a| validate_presence a }
        end

        private

        def option_keys
          [:type, :level, :format, :value, :align, :left, :indent, :start, :restart]
        end

      end
    end
  end
end
