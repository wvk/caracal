require 'nokogiri'

require 'caracal/renderers/xml_renderer'


module Caracal
  module Renderers
    class FontRelationshipsRenderer < XmlRenderer
      FONT_RELATIONSHIP_TYPE = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font'

      # This method produces the xml required for the `word/_rels/fontTable.xml.rels`
      # sub-document, which links the font table to the embedded font files.
      #
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          xml.Relationships root_options do
            document.embedded_fonts.each do |embedded|
              xml.Relationship 'Id' => embedded.rel_id, 'Type' => FONT_RELATIONSHIP_TYPE, 'Target' => embedded.target
            end
          end
        end
        builder.to_xml save_options
      end

      private

      def root_options
        { 'xmlns' => 'http://schemas.openxmlformats.org/package/2006/relationships' }
      end
    end
  end
end
