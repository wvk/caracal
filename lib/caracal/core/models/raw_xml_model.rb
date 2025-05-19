
module Caracal
  module Core
    module Models

      # This class handles block options passed to the page margins
      # method.
      #
      class RawXmlModel < BorderModel
        #-------------------------------------------------------------
        # Configuration
        #-------------------------------------------------------------

        def initialize(str, &block)
          @raw_xml = str
          opts = {}
          super opts, &block
        end

        def to_s
          @raw_xml.to_s
        end
      end

    end
  end
end
