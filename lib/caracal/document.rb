require 'open-uri'
require 'zip'

require 'caracal/header'
require 'caracal/footer'

require 'caracal/core/bookmarks'
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

    HEADER_FOOTER_TYPES = %i(default first)

    # Returns the header of the given type, evaluating the block on it.
    # Type :first is the header of a different first page.
    def header(type: :default, &block)
      header_or_footer headers, Header, type, &block
    end

    # Returns the footer of the given type, evaluating the block on it.
    def footer(type: :default, &block)
      header_or_footer footers, Footer, type, &block
    end

    def headers
      @headers ||= {}
    end

    def footers
      @footers ||= {}
    end

    # Gives the first page its own header and footer, which stay blank
    # unless defined with `header type: :first` or `footer type: :first`.
    def different_first_page(value = true)
      @different_first_page = value
    end

    def different_first_page?
      !!(@different_first_page or headers.key? :first or footers.key? :first)
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

    def header_or_footer(parts, klass, type, &block)
      type = type.to_sym
      unless HEADER_FOOTER_TYPES.include? type
        raise Caracal::Errors::InvalidModelError, "#{klass.name.split('::').last.downcase} type must be one of #{HEADER_FOOTER_TYPES.inspect}"
      end

      part = parts[type] ||= klass.new(index: parts.size + 1, type: type, document: self).tap {|hf| relationship hf.relationship_params }
      part.configure(&block)
    end

    # Page numbers are appended to the default footer, which is created if
    # necessary. A different first page gets (blank) first-page parts.
    def prepare_headers_and_footers
      footer if page_number_show
      footers[:default]&.page_number_paragraph = page_number_paragraph

      if different_first_page?
        header type: :first
        footer type: :first
      end
    end

    #============ RENDERERS ===============================

    def render_app(zip)
      content = ::Caracal::Renderers::AppRenderer.render self

      zip.put_next_entry 'docProps/app.xml'
      zip.write content
    end

    def render_content_types(zip)
      content = ::Caracal::Renderers::ContentTypesRenderer.render self

      zip.put_next_entry '[Content_Types].xml'
      zip.write content
    end

    def render_core(zip)
      content = ::Caracal::Renderers::CoreRenderer.render self

      zip.put_next_entry 'docProps/core.xml'
      zip.write content
    end

    def render_custom(zip)
      content = ::Caracal::Renderers::CustomRenderer.render self

      zip.put_next_entry 'docProps/custom.xml'
      zip.write content
    end

    def render_document(zip)
      content = ::Caracal::Renderers::DocumentRenderer.render self

      zip.put_next_entry 'word/document.xml'
      zip.write content
    end

    def render_fonts(zip)
      content = ::Caracal::Renderers::FontsRenderer.render self

      zip.put_next_entry 'word/fontTable.xml'
      zip.write content
    end

    def render_embedded_fonts(zip)
      embedded_fonts = self.embedded_fonts
      return if embedded_fonts.empty?

      embedded_fonts.each do |embedded|
        zip.put_next_entry "word/#{embedded.target}"
        zip.write embedded.content
      end

      content = ::Caracal::Renderers::FontRelationshipsRenderer.render self

      zip.put_next_entry 'word/_rels/fontTable.xml.rels'
      zip.write content
    end

    def render_header(zip)
      relationships_by_type(:header).each do |rel|
        content = ::Caracal::Renderers::HeaderRenderer.render rel.owner

        zip.put_next_entry "word/#{rel.formatted_target}"
        zip.write content
      end
    end

    def render_footer(zip)
      relationships_by_type(:footer).each do |rel|
        content = ::Caracal::Renderers::FooterRenderer.render rel.owner

        zip.put_next_entry "word/#{rel.formatted_target}"
        zip.write content
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
          content = URI.open(rel.relationship_target).read
        end

        zip.put_next_entry "word/#{rel.formatted_target}"
        zip.write content
      end
    end

    def render_numbering(zip)
      content = ::Caracal::Renderers::NumberingRenderer.render self

      zip.put_next_entry 'word/numbering.xml'
      zip.write content
    end

    def render_package_relationships(zip)
      content = ::Caracal::Renderers::PackageRelationshipsRenderer.render self

      zip.put_next_entry '_rels/.rels'
      zip.write content
    end

    def render_relationships(zip)
      content = ::Caracal::Renderers::RelationshipsRenderer.render self

      zip.put_next_entry 'word/_rels/document.xml.rels'
      zip.write content
    end

    def render_header_relationships(zip)
      (relationships_by_type(:header) + relationships_by_type(:footer)).each do |rel|
        part = rel.owner

        if part and part.relationships.any?
          content = ::Caracal::Renderers::RelationshipsRenderer.render part

          zip.put_next_entry "word/_rels/#{rel.formatted_target}.rels"
          zip.write content
        end
      end
    end

    def render_settings(zip)
      content = ::Caracal::Renderers::SettingsRenderer.render self

      zip.put_next_entry 'word/settings.xml'
      zip.write content
    end

    def render_styles(zip)
      content = ::Caracal::Renderers::StylesRenderer.render self

      zip.put_next_entry 'word/styles.xml'
      zip.write content
    end

    def render_theme(zip)
      zip.put_next_entry 'word/theme/theme1.xml'
      zip.write ::Caracal::Renderers::ThemeRenderer.render(self, document_theme)
    end

  end
end
