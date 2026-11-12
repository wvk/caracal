require 'caracal/core/models/text_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate link data.
      class LinkModel < TextModel
        use_prefix :link

        DEFAULT_LINK_COLOR     = '1155cc'
        DEFAULT_LINK_UNDERLINE = true

        has_string_attribute :href

        has_boolean_attribute :internal

        # readers (create aliases for superclass methods to conform
        # to expected naming convention.)
        alias_method :link_content,         :text_content
        alias_method :link_font,            :text_font
        alias_method :link_color,           :text_color
        alias_method :link_size,            :text_size
        alias_method :link_bold,            :text_bold
        alias_method :link_italic,          :text_italic
        alias_method :link_underline,       :text_underline
        alias_method :link_bgcolor,         :text_bgcolor
        alias_method :link_highlight_color, :text_highlight_color
        alias_method :link_vertical_align,  :text_vertical_align

        # initialization
        def initialize(options={}, &block)
          super options, &block

          # a character style formats the link instead of the defaults
          unless text_style
            @text_color     = DEFAULT_LINK_COLOR     if text_color.nil?
            @text_underline = DEFAULT_LINK_UNDERLINE if text_underline.nil?
          end
        end

        #========== STATE HELPERS =========================

        def external?
          !link_internal
        end

        #========== VALIDATION ============================

        def valid?
          [:content, :href].all? {|a| validate_presence a } and self.valid_highlight_color?
        end

        private

        def option_keys
          (super + [:internal, :href]).flatten
        end

      end
    end
  end
end
