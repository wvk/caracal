require 'nokogiri'
require 'caracal/renderers/xml_renderer'

module Caracal
  module Renderers
    class CoreRenderer < XmlRenderer
      W3CDTF = { 'xsi:type' => 'dcterms:W3CDTF' }

      # This method produces the xml required for the `docProps/core.xml`
      # sub-document.
      #
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          xml['cp'].coreProperties root_options do
            xml['dc'].title           xml_safe(title)
            xml['dc'].subject         xml_safe(document.subject)          if present? document.subject
            xml['dc'].creator         xml_safe(document.creator)          if present? document.creator
            xml['cp'].keywords        xml_safe(keywords)                  if present? keywords
            xml['dc'].description     xml_safe(document.description)      if present? document.description
            xml['cp'].lastModifiedBy  xml_safe(document.last_modified_by) if present? document.last_modified_by
            xml['dcterms'].created    w3cdtf(document.created),  W3CDTF   if present? document.created
            xml['dcterms'].modified   w3cdtf(document.modified), W3CDTF   if present? document.modified
          end
        end
        builder.to_xml save_options
      end


      private

      # The title falls back to the file name.
      def title
        present?(document.title) ? document.title : document.name
      end

      # Several keywords are separated by commas.
      def keywords
        Array(document.keywords).join ', '
      end

      def present?(value)
        !value.to_s.empty?
      end

      def w3cdtf(value)
        Caracal::Core::CoreProperties.w3cdtf value
      end

      def root_options
        {
          'xmlns:cp'        => 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties',
          'xmlns:dc'        => 'http://purl.org/dc/elements/1.1/',
          'xmlns:dcterms'   => 'http://purl.org/dc/terms/',
          'xmlns:dcmitype'  => 'http://purl.org/dc/dcmitype/',
          'xmlns:xsi'       => 'http://www.w3.org/2001/XMLSchema-instance'
        }
      end

    end
  end
end
