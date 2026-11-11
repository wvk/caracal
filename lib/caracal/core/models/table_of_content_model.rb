require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # table of contents data.
      #
      class TableOfContentModel < BaseModel
        use_prefix :toc

        has_string_attribute  :legend,      default: nil
        has_integer_attribute :start_level, default: 1
        has_integer_attribute :end_level,   default: 3
        has_string_attribute  :placeholder, default: '#' # shown as page number until Word updates the TOC

        def initialize(options={}, &block)
          @toc_start_level = DEFAULT_TOC_START_LEVEL
          @toc_end_level   = DEFAULT_TOC_END_LEVEL
          @toc_legend      = DEFAULT_TOC_LEGEND
          @toc_placeholder = DEFAULT_TOC_PLACEHOLDER

          super options, &block
        end

        #========== STATE HELPER ===========================

        def includes?(level)
          (toc_start_level..toc_end_level).include? level
        end

        #========== VALIDATION ============================

        def valid?
          [:start_level, :end_level].each do |method|
            value = send "toc_#{method}"
            return false if value <= 0 || value > 6
          end
          toc_start_level <= toc_end_level
        end

        private

        def option_keys
          [:start_level, :end_level, :legend, :placeholder]
        end

      end
    end
  end
end
