require 'nokogiri'

require 'caracal/renderers/document_renderer'


module Caracal
  module Renderers
    # Produces the xml for the `word/footnotes.xml` sub-document: the
    # separator lines above the footnotes, then the footnotes.
    class FootnotesRenderer < DocumentRenderer

      def to_xml
        builder = ::Nokogiri::XML::Builder.with(declaration_xml) do |xml|
          w = xml['w']
          w.footnotes root_options do
            render_separator w, -1, 'separator'             # above the footnotes
            render_separator w,  0, 'continuationSeparator' # above a footnote continued from the previous page

            document.contents.each do |model|
              w.footnote 'w:id' => document.id_for(model) do
                render_paragraph xml, model
              end
            end
          end
        end
        builder.to_xml save_options
      end

      private

      # footnotes have no page or column breaks
      def render_pagebreak(xml, model, **options); end

      def render_separator(w, id, type)
        w.footnote 'w:type' => type, 'w:id' => id do
          w.p paragraph_options do
            w.pPr do
              w.spacing 'w:after' => 0, 'w:line' => 240, 'w:lineRule' => 'auto'
            end
            w.r run_options do
              w.send type
            end
          end
        end
      end

    end
  end
end
