require 'nokogiri'

require 'caracal/renderers/document_renderer'


module Caracal
  module Renderers
    class HeaderRenderer < DocumentRenderer

      #-------------------------------------------------------------
      # Public Methods
      #-------------------------------------------------------------

      # This method produces the xml required for a `word/headerN.xml`
      # sub-document.
      #
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          xml['w'].send root_element, root_options do
            contents.each do |model|
              send render_method_for_model(model), xml, model
            end

            # Word requires a header or footer to end with a paragraph
            if contents.empty? or contents.last.is_a? Caracal::Core::Models::TableModel
              xml['w'].p paragraph_options do
                xml['w'].pPr do
                  xml['w'].pStyle 'w:val' => paragraph_style
                end
              end
            end
          end
        end
        builder.to_xml(save_options)
      end

      def render_pagebreak(xml, model); end
      def render_columnbreak(xml, model); end

      #-------------------------------------------------------------
      # Private Methods
      #-------------------------------------------------------------
      private

      def root_element
        'hdr'
      end

      def paragraph_style
        'Header'
      end

      def contents
        document.contents
      end

    end
  end
end


