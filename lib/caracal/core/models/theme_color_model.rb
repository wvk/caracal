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

        # Hex value of `hex` with this color's themeTint and themeShade applied.
        # Per ECMA-376 Part 1, 17.3.2.6 (color), both modify the HSL luminance
        # with a 0..255 hex factor f = value/255: tint L' = L*f + (1-f), shade L' = L*f.
        def adjust(hex)
          return hex unless hex.to_s.match?(/\A\h{6}\z/) and (theme_color_tint or theme_color_shade)

          h, s, l = self.class.rgb_to_hsl hex.scan(/../).map { |c| c.hex / 255.0 }
          if (f = factor theme_color_tint)
            l = l * f + (1 - f)
          end
          if (f = factor theme_color_shade)
            l = l * f
          end
          self.class.hsl_to_rgb(h, s, l).map { |c| '%02X' % (c * 255).round }.join
        end

        def self.rgb_to_hsl(rgb)
          max, min = rgb.max, rgb.min
          l = (max + min) / 2
          return [0.0, 0.0, l] if max == min

          d = max - min
          s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
          r, g, b = rgb
          h = case max
              when r then (g - b) / d + (g < b ? 6 : 0)
              when g then (b - r) / d + 2
              else        (r - g) / d + 4
              end
          [h / 6, s, l]
        end

        def self.hsl_to_rgb(h, s, l)
          return [l, l, l] if s.zero?

          q = l < 0.5 ? l * (1 + s) : l + s - l * s
          p = 2 * l - q
          [h + 1.0 / 3, h, h - 1.0 / 3].map do |t|
            t += 1 if t < 0
            t -= 1 if t > 1
            if t < 1.0 / 6 then p + (q - p) * 6 * t
            elsif t < 0.5  then q
            elsif t < 2.0 / 3 then p + (q - p) * (2.0 / 3 - t) * 6
            else p
            end
          end
        end

        def valid?
          validate_presence :color and
              validate_inclusion :ref, within: REFS, allow_nil: false
        end


        private

        def factor(value)
          value.to_s.hex / 255.0 if value.to_s.match?(/\A\h{1,2}\z/)
        end

        def option_keys
          [:ref, :tint, :shade, :color, :val]
        end

      end
    end
  end
end
