require 'caracal/renderers/header_renderer'


module Caracal
  module Renderers
    # Produces the xml for a `word/footerN.xml` sub-document.
    class FooterRenderer < HeaderRenderer

      private

      def root_element
        'ftr'
      end

      def paragraph_style
        'Footer'
      end

    end
  end
end
