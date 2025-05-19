module Caracal
  module Core
    module Models
      module HasMargins
        ATTRS = %i(top left right bottom)

        def has_margins(top: nil, left: nil, right: nil, bottom: nil)
          self.has_integer_attribute :top,    default: top
          self.has_integer_attribute :left,   default: left
          self.has_integer_attribute :right,  default: right
          self.has_integer_attribute :bottom, default: bottom
        end
      end
    end
  end
end
