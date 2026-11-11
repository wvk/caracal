require 'nokogiri'
require 'caracal/renderers/xml_renderer'

module Caracal
  module Renderers
    class ContentTypesRenderer < XmlRenderer

      # This method produces the xml required for the `_[ContentTypes].xml` sub-document.
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          xml.Types root_options do
            xml.Default 'Extension' => 'gif',  'ContentType' => 'image/gif'
            xml.Default 'Extension' => 'jpeg', 'ContentType' => 'image/jpeg'
            xml.Default 'Extension' => 'jpg',  'ContentType' => 'image/jpeg'
            xml.Default 'Extension' => 'odttf', 'ContentType' => 'application/vnd.openxmlformats-officedocument.obfuscatedFont'
            xml.Default 'Extension' => 'png',  'ContentType' => 'image/png'
            xml.Default 'Extension' => 'rels', 'ContentType' => 'application/vnd.openxmlformats-package.relationships+xml'
            xml.Default 'Extension' => 'ttf',  'ContentType' => 'application/x-font-ttf'
            xml.Default 'Extension' => 'xml',  'ContentType' => 'application/xml'
            xml.Override 'PartName' => '/docProps/app.xml',     'ContentType' => 'application/vnd.openxmlformats-officedocument.extended-properties+xml'
            xml.Override 'PartName' => '/docProps/core.xml',    'ContentType' => 'application/vnd.openxmlformats-package.core-properties+xml'
            xml.Override 'PartName' => '/docProps/custom.xml',  'ContentType' => 'application/vnd.openxmlformats-officedocument.custom-properties+xml'
            xml.Override 'PartName' => '/word/document.xml',    'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml'
            xml.Override 'PartName' => '/word/header1.xml',     'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml'
            xml.Override 'PartName' => '/word/footer1.xml',     'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml'
            xml.Override 'PartName' => '/word/fontTable.xml',   'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml'
            xml.Override 'PartName' => '/word/numbering.xml',   'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml'
            xml.Override 'PartName' => '/word/settings.xml',    'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml'
            xml.Override 'PartName' => '/word/styles.xml',      'ContentType' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml'
            xml.Override 'PartName' => '/word/theme/theme1.xml', 'ContentType' => 'application/vnd.openxmlformats-officedocument.theme+xml'
          end
        end
        builder.to_xml save_options
      end

      private

      def root_options
        { 'xmlns' => 'http://schemas.openxmlformats.org/package/2006/content-types' }
      end

    end
  end
end
