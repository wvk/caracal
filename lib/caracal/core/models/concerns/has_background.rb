require 'caracal/core/models/theme_color_model'

module Caracal
  module Core
    module Models
      module HasBackground
        ATTRS    = %i(bgcolor bgstyle theme_bgcolor)
        BGSTYLES = %i(clear solid horzStripe vertStripe reverseDiagStripe
            diagStripe horzCross diagCross thinHorzStripe thinVertStripe
            thinReverseDiagStripe thinDiagStripe thinHorzCross thinDiagCross pct5 pct10
            pct12 pct15 pct20 pct25 pct30 pct35 pct37 pct40 pct45 pct50 pct55 pct60 pct62
            pct65 pct70 pct75 pct80 pct85 pct87 pct90 pct95)

        def self.included(base)
          base.has_model_attribute :theme_bgcolor,
              model: Caracal::Core::Models::ThemeColorModel

          base.has_string_attribute :bgcolor

          base.has_symbol_attribute :bgstyle
        end

        def valid_bgstyle?
          validate_inclusion :bgstyle, within: BGSTYLES
        end
      end

    end
  end
end
