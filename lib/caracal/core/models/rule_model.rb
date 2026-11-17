require 'caracal/core/models/border_model'


module Caracal
  module Core
    module Models

      # This class handles block options passed to the page margins
      # method.
      #
      class RuleModel < BorderModel
        DEFAULT_BORDER_SIZE    = 4
        DEFAULT_BORDER_SPACING = 1

        ALIGNS = %i(left center right)

        #-------------------------------------------------------------
        # Configuration
        #-------------------------------------------------------------

        has_integer_attribute :width  # twips; the full width when nil
        has_symbol_attribute  :align, default: :center
        has_integer_attribute :top    # spacing above, twips
        has_integer_attribute :bottom # spacing below, twips
        has_integer_attribute :height # exact height of the rule's paragraph, twips

        # aliases
        alias_method :rule_color,    :border_color
        alias_method :rule_size,     :border_size
        alias_method :rule_spacing,  :border_spacing
        alias_method :rule_line,     :border_line
        alias_method :rule_width,    :border_width
        alias_method :rule_top,      :border_top
        alias_method :rule_bottom,   :border_bottom
        alias_method :rule_height,   :border_height
        alias_method :rule_align,    :border_align

        # the width available to the rule, set for rules in table cells
        attr_reader :rule_container_width

        def initialize(options={}, &block)
          @border_align = DEFAULT_BORDER_ALIGN
          super options, &block
        end

        def calculate_width(container_width, _container)
          @rule_container_width = container_width
        end

        # The start and end indents placing a rule of the given width in
        # the available width, or nil for a full-width rule.
        def indents(available_width)
          free = available_width.to_i - rule_width.to_i
          return if rule_width.nil? or free <= 0

          start = { left: 0, center: free / 2, right: free }[rule_align]
          { start: start, end: free - start }
        end

        def valid?
          minimums = { width: 0, height: 0, top: -1, bottom: -1 } # values must exceed these
          super and validate_inclusion(:align, within: ALIGNS) and
              minimums.all? {|dim, min| validate_size dim, at_least: min, allow_nil: true }
        end

        private

        def option_keys
          super + %i(width align top bottom height)
        end
      end

    end
  end
end
