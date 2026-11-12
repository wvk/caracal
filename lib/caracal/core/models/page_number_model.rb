require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class handles block options passed to the page_numbers
      # method.
      #
      class PageNumberModel < BaseModel
        use_prefix :page_number

        has_symbol_attribute :align, default: :center
        has_boolean_attribute :show, default: false
        has_string_attribute :label
        has_integer_attribute :label_size  # in half points
        has_integer_attribute :number_size # in half points

        PAGE_NUMBER_ALIGNS = [:left, :center, :right]

        # initialization
        def initialize(options={}, &block)
          @page_number_align        = DEFAULT_PAGE_NUMBER_ALIGN
          @page_number_label        = DEFAULT_PAGE_NUMBER_LABEL
          @page_number_label_size   = DEFAULT_PAGE_NUMBER_LABEL_SIZE
          @page_number_number_size  = DEFAULT_PAGE_NUMBER_NUMBER_SIZE
          @page_number_show         = DEFAULT_PAGE_NUMBER_SHOW

          super options, &block
        end

        #=============== SETTERS ==============================

        def label(value)
          @page_number_label = value.to_s.strip   # renderer will enforce trailing space
        end

        def label_size(value)
          @specific_size_given = true
          @page_number_label_size = size_value value
        end

        def number_size(value)
          @specific_size_given = true
          @page_number_number_size = size_value value
        end

        def size(value)
          @size_given = true
          @page_number_label_size = @page_number_number_size = size_value(value)
        end

        #=============== VALIDATION ===========================

        def valid?
          validate('size and label_size/number_size are mutually exclusive') { not (@size_given and @specific_size_given) } and
            (not page_number_show or validate_inclusion :align, within: PAGE_NUMBER_ALIGNS)
        end

        private

        def size_value(value)
          v = value.to_i
          v unless v == 0
        end

        def option_keys
          [:align, :label, :label_size, :number_size, :show]
        end

      end
    end
  end
end
