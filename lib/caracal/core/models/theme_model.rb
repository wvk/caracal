require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models
      class ThemeModel < BaseModel
        use_prefix :theme

        COLORS = [
          :dark1, :light1, :dark2, :light2,
          :text1, :background, :text2, :background2,
          :accent1, :accent2, :accent3,  :accent4, :accent5, :accent6,
          :hyperlink, :visited_hyperlink
        ]

        has_string_attribute :name,          default: 'Caracal'
        has_string_attribute :color_text1,   default: '000000'
        has_string_attribute :color_background1, default: 'FFFFFF'
        has_string_attribute :color_text2,   default: '707173'
        has_string_attribute :color_background2, default: 'FFFFFF'
        has_string_attribute :color_accent1, default: '00539B'
        has_string_attribute :color_accent2, default: '0096D6'
        has_string_attribute :color_accent3, default: 'F1CB00'
        has_string_attribute :color_accent4, default: 'C0311A'
        has_string_attribute :color_accent5, default: '00539B'
        has_string_attribute :color_accent6, default: '0096D6'
        has_string_attribute :color_hyperlink, default: '00539B'
        has_string_attribute :color_visited_hyperlink, default: '00539B'

        alias color_dark1 color_text1
        alias color_dark2 color_text2
        alias color_light1 color_background1
        alias color_light2 color_background2

        alias theme_color_dark1  theme_color_text1
        alias theme_color_dark2  theme_color_text2
        alias theme_color_light1 theme_color_background1
        alias theme_color_light2 theme_color_background2


        def initialize(options = {}, &block)
          @theme_name              = DEFAULT_THEME_NAME
          @theme_color_text1       = DEFAULT_THEME_COLOR_TEXT1
          @theme_color_background1 = DEFAULT_THEME_COLOR_BACKGROUND1
          @theme_color_text2       = DEFAULT_THEME_COLOR_TEXT2
          @theme_color_background2 = DEFAULT_THEME_COLOR_BACKGROUND2
          @theme_color_accent1     = DEFAULT_THEME_COLOR_ACCENT1
          @theme_color_accent2     = DEFAULT_THEME_COLOR_ACCENT2
          @theme_color_accent3     = DEFAULT_THEME_COLOR_ACCENT3
          @theme_color_accent4     = DEFAULT_THEME_COLOR_ACCENT4
          @theme_color_accent5     = DEFAULT_THEME_COLOR_ACCENT5
          @theme_color_accent6     = DEFAULT_THEME_COLOR_ACCENT6
          @theme_color_hyperlink   = DEFAULT_THEME_COLOR_HYPERLINK
          @theme_color_visited_hyperlink = DEFAULT_THEME_COLOR_VISITED_HYPERLINK

          super options, &block
        end

        private

        def option_keys
          COLORS + [:name]
        end

      end
    end
  end
end
