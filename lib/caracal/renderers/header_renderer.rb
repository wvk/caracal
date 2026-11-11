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

      def root_options
        {
          'xmlns:mc'  => 'http://schemas.openxmlformats.org/markup-compatibility/2006',
          'xmlns:o'   => 'urn:schemas-microsoft-com:office:office',
          'xmlns:r'   => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
          'xmlns:m'   => 'http://schemas.openxmlformats.org/officeDocument/2006/math',
          'xmlns:v'   => 'urn:schemas-microsoft-com:vml',
          'xmlns:wp'  => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
          'xmlns:w10' => 'urn:schemas-microsoft-com:office:word',
          'xmlns:w'   => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
          'xmlns:wne' => 'http://schemas.microsoft.com/office/word/2006/wordml',
          'xmlns:sl'  => 'http://schemas.openxmlformats.org/schemaLibrary/2006/main',
          'xmlns:a'   => 'http://schemas.openxmlformats.org/drawingml/2006/main',
          'xmlns:pic' => 'http://schemas.openxmlformats.org/drawingml/2006/picture',
          'xmlns:c'   => 'http://schemas.openxmlformats.org/drawingml/2006/chart',
          'xmlns:lc'  => 'http://schemas.openxmlformats.org/drawingml/2006/lockedCanvas',
          'xmlns:dgm' => 'http://schemas.openxmlformats.org/drawingml/2006/diagram'
        }
      end

    end
  end
end


