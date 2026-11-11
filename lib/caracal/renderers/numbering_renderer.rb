require 'nokogiri'

require 'caracal/core/models/list_style_model'
require 'caracal/core/models/list_model'
require 'caracal/renderers/xml_renderer'


module Caracal
  module Renderers
    class NumberingRenderer < XmlRenderer
      # This method produces the xml required for the `word/numbering.xml` sub-document.
      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          w = xml['w']

          w.numbering root_options do
            document.with_heading_numbering do |model|
              w.abstractNum 'w:abstractNumId' => model.id do
                w.multiLevelType 'w:val' => 'multilevel'
                w.name 'w:val' => model.heading_numbering_name

                model.heading_numberings.each_value do |num|
                  w.lvl 'w:ilvl' => num[:ilvl] do
                    w.start      'w:val' => 1
                    w.numFmt     'w:val' => num[:fmt]
                    # no lvlRestart: by default, a level restarts whenever a higher level is used
                    w.pStyle     'w:val' => num[:style_id]
                    w.suff       'w:val' => num[:suff]
                    w.lvlText    'w:val' => num[:lvl_text]
                    w.lvlJc      'w:val' => 'left'
                    w.pPr do
                      w.ind 'w:left' => 0, 'w:hanging' => 0
                    end
                  end
                end
              end
            end

            # add abstract numbering definitions
            list_numberings = document.toplevel_lists.map(&:numberings).reduce({}, :merge)
            list_numberings.each do |id, level_map|
              w.abstractNum 'w:abstractNumId' => id do
                w.multiLevelType 'w:val' => 'hybridMultilevel'
                level_map.sort.each do |(level, type)|
                  if s = document.find_list_style(type, level)
                    w.lvl          'w:ilvl' => s.style_level do
                      w.start      'w:val' => s.style_start
                      w.numFmt     'w:val' => s.style_format
                      w.lvlRestart 'w:val' => s.style_restart
                      w.lvlText    'w:val' => s.style_value
                      w.lvlJc      'w:val' => s.style_align
                      w.pPr do
                        w.ind 'w:left' => s.style_left, 'w:firstLine' => s.style_indent
                      end
                      w.rPr do
                        w.u 'w:val' => 'none'
                      end
                    end
                  end
                end
              end
            end

            # bind concrete numberings to abstract definitions. Both share the same id.
            numbering_ids = list_numberings.keys
            document.with_heading_numbering {|model| numbering_ids.unshift model.id }
            numbering_ids.each do |i|
              w.num 'w:numId' => i do
                w.abstractNumId 'w:val' => i
              end
            end
          end
        end

        builder.to_xml(save_options)
      end

      private

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
