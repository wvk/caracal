require 'caracal/core/models/base_model'
require 'caracal/core/models/theme_model'

module Caracal
  module Core
    module Models

      class ThemeColorModel < BaseModel
        use_prefix :theme_color

        # ST_ThemeColor values
        REFS = %i(dark1 light1 dark2 light2 accent1 accent2 accent3 accent4 accent5 accent6
                  hyperlink followedHyperlink background1 text1 background2 text2 none)
        REF_ALIASES = { visited_hyperlink: :followedHyperlink, followed_hyperlink: :followedHyperlink, background: :background1 }

        has_symbol_attribute :ref

        has_string_attribute :shade
        has_string_attribute :tint
        has_string_attribute :color, default: 'auto'

        def initialize(*args, &block)
          first_arg = args.shift
          if first_arg.is_a? Symbol
            opts = (args.first || {}).merge ref: first_arg
          else
            opts = first_arg
          end
          super opts, &block
          @theme_color_color ||= DEFAULT_THEME_COLOR_COLOR
        end

        def calculate_color(theme)
          # TODO: apply tint and shade, if present
          theme.send "color_#{self.theme_color_ref}"
        end

        def theme_color_val
          self.theme_color_color
        end

        def val(arg)
          self.color arg
        end

        def ref(value)
          value = value.to_s.to_sym unless value.nil?
          @theme_color_ref = REF_ALIASES.fetch(value, value)
        end

        def valid?
          validate_presence :color and
              validate_inclusion :ref, within: REFS, allow_nil: false
        end


        private

        def option_keys
          [:ref, :tint, :shade, :color, :val]
        end

        def hex_to_angle
          raise NotImplementedError
        end

      end
    end
  end
end
