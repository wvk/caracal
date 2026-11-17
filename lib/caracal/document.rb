require 'zip'

require 'caracal/header'
require 'caracal/footer'

require 'caracal/core/bookmarks'
require 'caracal/core/core_properties'
require 'caracal/core/custom_properties'
require 'caracal/core/file_name'
require 'caracal/core/fonts'
require 'caracal/core/iframes'
require 'caracal/core/ignorables'
require 'caracal/core/images'
require 'caracal/core/list_styles'
require 'caracal/core/lists'
require 'caracal/core/namespaces'
require 'caracal/core/page_breaks'
require 'caracal/core/page_numbers'
require 'caracal/core/page_settings'
require 'caracal/core/relationships'
require 'caracal/core/rules'
require 'caracal/core/styles'
require 'caracal/core/tables'
require 'caracal/core/table_of_contents'
require 'caracal/core/text'
require 'caracal/core/raw_xml'
require 'caracal/core/theme'
require 'caracal/core/heading_numbering'

require 'caracal/renderers/app_renderer'
require 'caracal/renderers/content_types_renderer'
require 'caracal/renderers/core_renderer'
require 'caracal/renderers/custom_renderer'
require 'caracal/renderers/document_renderer'
require 'caracal/renderers/fonts_renderer'
require 'caracal/renderers/font_relationships_renderer'
require 'caracal/renderers/header_renderer'
require 'caracal/renderers/footer_renderer'
require 'caracal/renderers/numbering_renderer'
require 'caracal/renderers/package_relationships_renderer'
require 'caracal/renderers/relationships_renderer'
require 'caracal/renderers/settings_renderer'
require 'caracal/renderers/styles_renderer'
require 'caracal/renderers/theme_renderer'


module Caracal
  class Document

    #------------------------------------------------------
    # Configuration
    #------------------------------------------------------

    # mixins (order is important)
    include Caracal::Core::CoreProperties
    include Caracal::Core::CustomProperties
    include Caracal::Core::FileName
    include Caracal::Core::Ignorables
    include Caracal::Core::Namespaces
    include Caracal::Core::Relationships

    include Caracal::Core::Fonts
    include Caracal::Core::PageSettings
    include Caracal::Core::PageNumbers
    include Caracal::Core::Styles
    include Caracal::Core::ListStyles
    include Caracal::Core::Theme

    include Caracal::Core::Bookmarks
    include Caracal::Core::IFrames
    include Caracal::Core::Images
    include Caracal::Core::Lists
    include Caracal::Core::PageBreaks
    include Caracal::Core::Rules
    include Caracal::Core::Tables
    include Caracal::Core::TableOfContents
    include Caracal::Core::Text
    include Caracal::Core::HeadingNumbering

    include Caracal::Core::RawXml


    attr_accessor :current_numbering_id

    #------------------------------------------------------
    # Public Class Methods
    #------------------------------------------------------

    #============ OUTPUT ==================================

    # This method renders a new Word document and returns it as a
    # a string.
    #
    def self.render(f_name = nil, &block)
      docx   = new f_name, &block
      buffer = docx.render

      buffer.rewind
      buffer.sysread
    end

    # This method renders a new Word document and saves it to the
    # file system.
    #
    def self.save(f_name = nil, &block)
      docx = new f_name, &block
      docx.save
    end

    # Returns the header, evaluating the block on it. With first: true it is
    # the header of the first page only; without a block that leaves the
    # first page's header blank.
    def header(first: false, &block)
      header_or_footer headers, Header, first, &block
    end

    # Returns the footer, evaluating the block on it. With first: true it is
    # the footer of the first page only.
    def footer(first: false, &block)
      header_or_footer footers, Footer, first, &block
    end

    def headers
      @headers ||= {}
    end

    def footers
      @footers ||= {}
    end

    # Whether the first page has its own header and footer (Word's
    # "Different First Page"): it has when a first-page header or footer is
    # given, or the page number is left off the first page.
    def title_page?
      !!(headers.key? :first or footers.key? :first or (page_number_show and not page_number_first_page))
    end

    #------------------------------------------------------
    # Public Instance Methods
    #------------------------------------------------------

    # This method instantiates a new word document.
    #
    def initialize(name = nil, &block)
      file_name name

      page_size
      page_margins top: 1440, bottom: 1440, left: 1440, right: 1440
      page_numbers

      self.current_numbering_id = 0

      [:font, :list_style, :namespace, :relationship, :style].each do |method|
        collection = self.class.send "default_#{method}s"
        collection.each do |item|
          send(method, item)
        end
      end

      if block_given?
        (block.arity < 1) ? instance_exec(&block) : block[self]
      end
    end


    #============ GETTERS =================================

    # This method returns an array of models which constitute the
    # set of instructions for producing the document content.
    #
    def contents
      @contents ||= []
    end

    # In justified paragraphs, Word spreads the words of a line that ends
    # in a line break across the line. false leaves such a line at its
    # natural width, as browsers do.
    def justify_lines_before_breaks(value)
      @justify_lines_before_breaks = value
    end

    def justify_lines_before_breaks?
      @justify_lines_before_breaks != false
    end

    def next_numbering_id
      self.current_numbering_id += 1
    end

    # numbering ids are handed out during rendering, so each rendering pass starts afresh
    def reset_numbering
      toplevel_lists.clear
      self.current_numbering_id = 0
      with_heading_numbering {|model| model.id = next_numbering_id }
    end

    # docPr/cNvPr ids are unique across body, headers and footers
    def next_drawing_id
      @drawing_counter = @drawing_counter.to_i + 1
    end

    # bookmark ids are unique across body, headers and footers
    def next_bookmark_id
      @bookmark_counter = @bookmark_counter.to_i + 1
    end

    #============ RENDERING ===============================

    # This method renders the word document instance into
    # a string buffer. Order is important!
    #
    def render
      register_nested_iframes contents
      reset_numbering
      @drawing_counter = 0
      @bookmark_counter = 0
      prepare_headers_and_footers

      buffer = ::Zip::OutputStream.write_buffer do |zip|
        %w(package_relationships content_types app core custom fonts embedded_fonts header footer settings styles document relationships header_relationships media numbering theme).each do |what|
          send "render_#{what}", zip
        end
      end
    end


    #============ SAVING ==================================

    def save
      buffer = render

      File.open(path, 'wb') { |f| f.write buffer.string }
    end


    #------------------------------------------------------
    # Private Instance Methods
    #------------------------------------------------------
    private

    # Default parts are header1.xml and footer1.xml, first-page parts
    # header2.xml and footer2.xml.
    def header_or_footer(parts, klass, first, &block)
      type = first ? :first : :default
      part = parts[type] ||= klass.new(index: (first ? 2 : 1), type: type, document: self)
      part.configure(&block)
    end

    # Iframes inside table cells can't register their namespaces on their
    # part when they're created, and a first-page copy shows another part's
    # iframes, so collect them here.
    def register_nested_iframes(models, part = self)
      models.each do |model|
        case model
        when Caracal::Core::Models::IFrameModel
          model.namespaces.each {|prefix, href| part.namespace prefix: prefix, href: href }
          model.ignorables.each {|prefix| part.ignorable prefix }
        when Caracal::Core::Models::TableModel
          model.cells.each {|cell| register_nested_iframes cell.contents, part }
        end
      end
    end

    # Decides which header and footer parts the document writes. The page
    # number goes below the default footer's content, which is created if
    # necessary, and on the first page too unless first_page: false. A first
    # page without its own header or footer shows the default one's content.
    def prepare_headers_and_footers
      footer if page_number_show

      parts = [headers[:default], footers[:default]]
      if title_page?
        parts << (headers[:first] || first_page_copy(Header, headers[:default]))
        parts << (footers[:first] || first_page_copy(Footer, footers[:default]))
      end
      parts.compact!

      parts.grep(Footer).each do |part|
        shown = (part.type == :default or page_number_first_page)
        part.page_number_paragraph = (page_number_paragraph if shown)
      end

      # a blank first-page part is left out, like upstream caracal does: with
      # titlePg set, the first page shows nothing where no part is referenced
      parts.reject! do |part|
        part.type == :first and part.contents.empty? and not (part.is_a? Footer and part.page_number_paragraph)
      end

      parts.each {|part| register_nested_iframes part.contents, part }

      # keep the relationships of parts still written, so renderings agree
      wanted = parts.to_h {|part| [part.relationship_params[:target], part] }
      %i(header footer).each do |kind|
        relationships_by_type(kind).each do |rel|
          relationships.delete rel unless wanted[rel.relationship_target].equal? rel.owner
        end
      end
      parts.each {|part| relationship part.relationship_params }
    end

    # A first-page part showing the given default part's content, or nil
    # when there is nothing to show.
    def first_page_copy(klass, source)
      return if source.nil?
      return if source.contents.empty? and not (klass == Footer and page_number_show and page_number_first_page)

      copies = (@first_page_copies ||= {})
      copies[klass] = klass.new(index: 2, type: :first, document: self, source: source) unless copies[klass]&.source.equal? source
      copies[klass]
    end

    #============ RENDERERS ===============================

    # Adds a part to the package. Giving rubyzip the size up front stops
    # rubyzip 3 from adding a zip64 extra field "just in case" to every
    # entry, which LibreOffice 7.4 and older can't read.
    def write_entry(zip, name, content)
      content = content.to_s
      entry   = ::Zip::Entry.new '', name
      entry.size = content.bytesize

      zip.put_next_entry entry
      zip.write content
    end

    def render_app(zip)
      content = ::Caracal::Renderers::AppRenderer.render self

      write_entry zip, 'docProps/app.xml', content
    end

    def render_content_types(zip)
      content = ::Caracal::Renderers::ContentTypesRenderer.render self

      write_entry zip, '[Content_Types].xml', content
    end

    def render_core(zip)
      content = ::Caracal::Renderers::CoreRenderer.render self

      write_entry zip, 'docProps/core.xml', content
    end

    def render_custom(zip)
      content = ::Caracal::Renderers::CustomRenderer.render self

      write_entry zip, 'docProps/custom.xml', content
    end

    def render_document(zip)
      content = ::Caracal::Renderers::DocumentRenderer.render self

      write_entry zip, 'word/document.xml', content
    end

    def render_fonts(zip)
      content = ::Caracal::Renderers::FontsRenderer.render self

      write_entry zip, 'word/fontTable.xml', content
    end

    def render_embedded_fonts(zip)
      embedded_fonts = self.embedded_fonts
      return if embedded_fonts.empty?

      embedded_fonts.each do |embedded|
        write_entry zip, "word/#{embedded.target}", embedded.content
      end

      content = ::Caracal::Renderers::FontRelationshipsRenderer.render self

      write_entry zip, 'word/_rels/fontTable.xml.rels', content
    end

    def render_header(zip)
      relationships_by_type(:header).each do |rel|
        content = ::Caracal::Renderers::HeaderRenderer.render rel.owner

        write_entry zip, "word/#{rel.formatted_target}", content
      end
    end

    def render_footer(zip)
      relationships_by_type(:footer).each do |rel|
        content = ::Caracal::Renderers::FooterRenderer.render rel.owner

        write_entry zip, "word/#{rel.formatted_target}", content
      end
    end

    def render_media(zip)
      images = relationships_by_type(:image) # get images from main doc
      relationships_by_type(:header).each do |rel| # get image rels from headers
        images.concat rel.owner.relationships_by_type(:image)
      end
      relationships_by_type(:footer).each do |rel| # get image rels from footers
        images.concat rel.owner.relationships_by_type(:image)
      end

      images.uniq(&:formatted_target).each do |rel|
        if rel.relationship_data.to_s.size > 0
          content = rel.relationship_data
        else
          # NOTICE: this potentially opens a web resource!
          content = Caracal::Utilities.read_resource rel.relationship_target
        end

        write_entry zip, "word/#{rel.formatted_target}", content
      end
    end

    def render_numbering(zip)
      content = ::Caracal::Renderers::NumberingRenderer.render self

      write_entry zip, 'word/numbering.xml', content
    end

    def render_package_relationships(zip)
      content = ::Caracal::Renderers::PackageRelationshipsRenderer.render self

      write_entry zip, '_rels/.rels', content
    end

    def render_relationships(zip)
      content = ::Caracal::Renderers::RelationshipsRenderer.render self

      write_entry zip, 'word/_rels/document.xml.rels', content
    end

    def render_header_relationships(zip)
      (relationships_by_type(:header) + relationships_by_type(:footer)).each do |rel|
        part = rel.owner

        if part and part.relationships.any?
          content = ::Caracal::Renderers::RelationshipsRenderer.render part

          write_entry zip, "word/_rels/#{rel.formatted_target}.rels", content
        end
      end
    end

    def render_settings(zip)
      content = ::Caracal::Renderers::SettingsRenderer.render self

      write_entry zip, 'word/settings.xml', content
    end

    def render_styles(zip)
      content = ::Caracal::Renderers::StylesRenderer.render self

      write_entry zip, 'word/styles.xml', content
    end

    def render_theme(zip)
      write_entry zip, 'word/theme/theme1.xml', ::Caracal::Renderers::ThemeRenderer.render(self, document_theme)
    end

  end
end
