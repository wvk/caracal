require 'caracal/core/models/theme_color_model'

module Caracal
  module Core
    module Models
      module HasColor
        ATTRS = %i(color theme_color)

        def self.included(base)
          base.has_model_attribute :theme_color,
              model: Caracal::Core::Models::ThemeColorModel

          base.has_string_attribute :color
        end
      end
    end
  end
end
