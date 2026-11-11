require 'nokogiri'
require 'caracal/renderers/xml_renderer'

module Caracal
  module Renderers
    class CustomRenderer < XmlRenderer
      I4_RANGE = -2**31...2**31

      # This method produces the xml required for the `docProps/custom.xml`
      # sub-document.
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          xml.Properties root_options do
            document.custom_props.each_with_index do |property, index|
              xml.property fmtid: '{D5CDD505-2E9C-101B-9397-08002B2CF9AE}', pid: index + 2, name: property.custom_property_name do
                case property.custom_property_type.downcase
                when  'text'
                  xml['vt'].lpwstr property.custom_property_value
                when 'date'
                  xml['vt'].filetime property.custom_property_date
                when 'number'
                  number = property.custom_property_number
                  if number.is_a? Integer and I4_RANGE.cover? number
                    xml['vt'].i4 number.to_s
                  else
                    xml['vt'].r8 number.to_f.to_s
                  end
                when 'boolean'
                  if %w(true false).include? property.custom_property_value.to_s
                    xml['vt'].bool property.custom_property_value.to_s
                  else
                    # Not a boolean sent, so reverting to string so docx will open
                    xml['vt'].lpwstr property.custom_property_value.to_s
                  end
                else
                  # Fail to string type
                  xml['vt'].lpwstr property.custom_property_value.to_s
                end
              end
            end
          end
        end
        builder.to_xml(save_options)
      end

      private

      def root_options
        {
          'xmlns'    => 'http://schemas.openxmlformats.org/officeDocument/2006/custom-properties',
          'xmlns:vt' => 'http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'
        }
      end

    end
  end
end
