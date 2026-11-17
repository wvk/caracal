require 'zip'

require 'caracal/header'
require 'caracal/footer'
require 'caracal/footnotes'

require 'caracal/core/bookmarks'
require 'caracal/core/core_properties'
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
require 'caracal/core/page_numbers'
require 'caracal/core/page_settings'
require 'caracal/core/relationships'
require 'caracal/core/rules'
require 'caracal/core/sections'
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
require 'caracal/renderers/footnotes_renderer'
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
    include Caracal::Core::Sections
    include Caracal::Core::Styles
    include Caracal::Core::ListStyles
    include Caracal::Core::Theme

    include Caracal::Core::Bookmarks
    include Caracal::Core::Frames
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

    # The footnotes part, word/footnotes.xml.
    def footnotes
      @footnotes ||= Footnotes.new(document: self)
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

    # The numbering definitions of iframes, renumbered as each is rendered.
    def iframe_numberings
      @iframe_numberings ||= []
    end

    # numbering ids are handed out during rendering, so each rendering pass starts afresh
    def reset_numbering
      toplevel_lists.clear
      iframe_numberings.clear
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
      prepare_footnotes

      buffer = ::Zip::OutputStream.write_buffer do |zip|
        %w(package_relationships content_types app core custom fonts embedded_fonts header footer settings styles document footnotes relationships header_relationships media numbering theme).each do |what|
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

    # Decides which header and footer parts the document writes and which
    # section refers to which. The document's header and footer start the
    # first section; a later section shows its own or else the previous
    # section's. The page number goes below the default footer's content,
    # which is created if necessary, and on the first page too unless
    # first_page: false. A first page without its own header or footer
    # shows the default one's content.
    def prepare_headers_and_footers
      footer if page_number_show

      chosen   = [] # [section, part, type]
      defaults = {} # part class => the default part the previous section shows
      sections.each_with_index do |section, index|
        section.references = []
        title_page = section.title_page? index.zero?

        { Header => [headers, section.headers], Footer => [footers, section.footers] }.each do |klass, (document_parts, own)|
          own   = document_parts.merge own if index.zero?
          slots = { default: own[:default] }
          defaults[klass] = own[:default] if own[:default]
          if title_page
            slots[:first] = own[:first] || first_page_copy(klass, defaults[klass], (section unless section.document_level?))
          end

          slots.each do |type, part|
            next if part.nil?

            if part.is_a? Footer
              part.page_number_paragraph = (page_number_paragraph if type == :default or page_number_first_page)
            end

            # the first section leaves a blank first-page part out, like
            # upstream caracal does: with titlePg set, the first page shows
            # nothing where no part is referenced. A later section's would
            # show an earlier section's part.
            blank = (part.contents.empty? and not (part.is_a? Footer and part.page_number_paragraph))
            next if type == :first and blank and index.zero?

            chosen << [section, part, type]
          end
        end
      end

      # the parts of sections follow the document's own header1 and header2
      parts = chosen.map {|_, part, _| part }.uniq
      [Header, Footer].each do |klass|
        parts.grep(klass).select(&:section).each_with_index {|part, i| part.index = 3 + i }
      end

      parts.each {|part| register_nested_iframes part.contents, part }

      # keep the relationships of parts still written, so renderings agree
      wanted = parts.to_h {|part| [part.relationship_params[:target], part] }
      %i(header footer).each do |kind|
        relationships_by_type(kind).each do |rel|
          relationships.delete rel unless wanted[rel.relationship_target].equal? rel.owner
        end
      end
      rels = parts.to_h {|part| [part, relationship(part.relationship_params)] }
      chosen.each {|section, part, type| section.references << [rels[part], type] }
    end

    # Numbers the footnotes in the order of their references. The document
    # writes a footnotes part only when it has footnotes.
    def prepare_footnotes
      footnotes.clear
      each_footnote(contents) {|model| footnotes.id_for model }

      if footnotes.contents.any?
        relationship footnotes.relationship_params
      else
        relationships_by_type(:footnotes).each {|rel| relationships.delete rel }
      end
    end

    # Yields the footnotes of paragraphs, list items and table cells in
    # document order.
    def each_footnote(models, &block)
      models.each do |model|
        case model
        when Caracal::Core::Models::ParagraphModel
          model.runs.grep(Caracal::Core::Models::FootnoteReferenceModel).each {|run| yield run.footnote }
        when Caracal::Core::Models::ListModel
          each_footnote model.recursive_items, &block
        when Caracal::Core::Models::TableModel
          model.cells.each {|cell| each_footnote cell.contents, &block }
        end
      end
    end

    # A first-page part showing the given default part's content, or nil
    # when there is nothing to show. A section's may be blank, as its
    # first page would otherwise show the previous section's.
    def first_page_copy(klass, source, section = nil)
      if section.nil?
        return if source.nil?
        return if source.contents.empty? and not (klass == Footer and page_number_show and page_number_first_page)
      end

      copies = (@first_page_copies ||= {})
      key    = [klass, section]
      copies[key] = klass.new(index: 2, type: :first, document: self, source: source, section: section) unless copies[key]&.source.equal? source
      copies[key]
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

    def render_footnotes(zip)
      relationships_by_type(:footnotes).each do |rel|
        part = rel.owner

        write_entry zip, "word/#{rel.formatted_target}", ::Caracal::Renderers::FootnotesRenderer.render(part)
        if part.relationships.any?
          write_entry zip, "word/_rels/#{rel.formatted_target}.rels", ::Caracal::Renderers::RelationshipsRenderer.render(part)
        end
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
