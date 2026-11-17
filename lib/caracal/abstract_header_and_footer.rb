require 'caracal/core/bookmarks'
require 'caracal/core/custom_properties'
require 'caracal/core/file_name'
require 'caracal/core/fonts'
require 'caracal/core/frames'
require 'caracal/core/iframes'
require 'caracal/core/ignorables'
require 'caracal/core/images'
require 'caracal/core/list_styles'
require 'caracal/core/lists'
require 'caracal/core/namespaces'
require 'caracal/core/page_breaks'
require 'caracal/core/page_settings'
require 'caracal/core/relationships'
require 'caracal/core/rules'
require 'caracal/core/styles'
require 'caracal/core/tables'
require 'caracal/core/text'
require 'caracal/core/raw_xml'

module Caracal
  class AbstractHeaderAndFooter

    include Caracal::Core::CustomProperties
    include Caracal::Core::FileName
    include Caracal::Core::Ignorables
    include Caracal::Core::Namespaces
    include Caracal::Core::Relationships

    include Caracal::Core::Fonts
    include Caracal::Core::PageSettings
    include Caracal::Core::Styles
    include Caracal::Core::ListStyles

    include Caracal::Core::Bookmarks
    include Caracal::Core::Frames
    include Caracal::Core::IFrames
    include Caracal::Core::Images
    include Caracal::Core::Lists
    include Caracal::Core::PageBreaks
    include Caracal::Core::Rules
    include Caracal::Core::Tables
    include Caracal::Core::Text
    include Caracal::Core::RawXml

    attr_reader :index, :type, :document, :source, :section

    # the document numbers the parts of sections when it renders
    attr_writer :index

    # A part with a source shows the source's content, e.g. a first page
    # without its own header shows the default header's content. A
    # section's part fits the section's page.
    def initialize(index: 1, type: :default, document: nil, source: nil, section: nil, &block)
      @index = index
      @type = type
      @document = document
      @source = source
      @section = section
      page_size
      page_margins top: 1440, bottom: 1440, left: 1440, right: 1440

      [:font, :list_style, :namespace, :style].each do |method|
        collection = self.class.send "default_#{ method }s"
        collection.each do |item|
          send(method, item)
        end
      end

      configure(&block)
    end

    # Evaluates a DSL block against this header or footer.
    def configure(&block)
      (block.arity < 1) ? instance_exec(&block) : block[self] if block
      self
    end

    def contents
      source ? source.contents : (@contents ||= [])
    end

    # Lists are numbered by the document, which owns numbering.xml.
    def list_numberings
      document.list_numberings
    end

    def list_starts
      document.list_starts
    end

    def iframe_numberings
      document.iframe_numberings
    end

    def next_numbering_id
      document.next_numbering_id
    end

    def next_drawing_id
      document.next_drawing_id
    end

    def next_bookmark_id
      document.next_bookmark_id
    end

    def find_list_style(type, level)
      document.find_list_style type, level
    end

    def document_theme
      document.document_theme
    end

    # Headers and footers span the page between its margins: their
    # section's page, or the document's.
    def page_content_width
      return super unless document

      page = section ? section.page : document
      page.page_width - page.page_margin_left - page.page_margin_right
    end
  end
end

