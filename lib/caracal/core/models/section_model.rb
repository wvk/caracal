require 'caracal/core/models/base_model'
require 'caracal/core/page_settings'
require 'caracal/errors'


module Caracal
  module Core
    module Models

      # This class handles the options passed to the section method: a
      # part of the document with its own page size, margins, columns,
      # headers and footers. A section ends where its model stands in the
      # document's contents. One made with nil for options has the
      # document's settings and no headers or footers of its own.
      #
      class SectionModel < BaseModel
        include Caracal::Core::PageSettings

        OPTIONS = %i(page_size page_margins columns header footer different_first_page)

        attr_reader :document
        attr_reader :headers
        attr_reader :footers
        attr_reader :section_different_first_page

        # the header and footer relationships the section's properties
        # refer to, with their types; set by the document before rendering
        attr_accessor :references

        # Options not given take the document's settings at this point.
        # The page comes first, so the headers and footers given as blocks
        # fit it.
        def initialize(options = nil, document:)
          @errors         = []
          @document       = document
          @document_level = options.nil?
          @headers        = {}
          @footers        = {}
          return if document_level?

          unless options.is_a? Hash and (options.keys - OPTIONS).empty?
            raise Caracal::Errors::InvalidModelError, "section takes the options #{OPTIONS.join ', '}."
          end

          size    = { width: document.page_width, height: document.page_height, orientation: document.page_orientation }
          margins = { top: document.page_margin_top, bottom: document.page_margin_bottom, left: document.page_margin_left, right: document.page_margin_right }
          page_size    size.merge(hash_option options, :page_size)
          page_margins margins.merge(hash_option options, :page_margins)
          if options.key? :columns
            columns options[:columns]
          elsif document.page_column_count
            page_columns document.page_column_count, spacing: document.page_column_spacing
          end

          different_first_page options[:different_first_page] if options.key? :different_first_page
          header options[:header] if options.key? :header
          footer options[:footer] if options.key? :footer
        end

        #=============== GETTERS ==============================

        # Whether the section has the document's settings.
        def document_level?
          @document_level
        end

        # The object holding the section's page settings.
        def page
          document_level? ? document : self
        end

        # Whether the section's first page has its own header and footer:
        # when asked to, or given a first-page header or footer. The first
        # section otherwise follows the document.
        def title_page?(first_section)
          return section_different_first_page unless section_different_first_page.nil?
          return true if headers.key? :first or footers.key? :first

          first_section ? document.title_page? : false
        end

        #=============== SETTERS ==============================

        # A column count, or a hash with count and spacing.
        def columns(value)
          if value.is_a? Hash and not (value.keys - %i(count spacing)).empty?
            raise Caracal::Errors::InvalidModelError, 'section columns takes a count or a hash with count and spacing.'
          end
          count, spacing = value.is_a?(Hash) ? value.values_at(:count, :spacing) : [value]
          page_columns count, **{ spacing: spacing }.compact
        end

        def different_first_page(value)
          unless [true, false].include? value
            raise Caracal::Errors::InvalidModelError, 'section different_first_page takes true or false.'
          end
          @section_different_first_page = value
        end

        def header(value)
          @headers = own_parts value, Caracal::Header
        end

        def footer(value)
          @footers = own_parts value, Caracal::Footer
        end

        private

        def hash_option(options, name)
          value = options.fetch(name, {})
          raise Caracal::Errors::InvalidModelError, "section #{name} takes a hash." unless value.is_a? Hash
          value
        end

        # The section's own header or footer parts by type, from a block,
        # a Caracal::Header or Caracal::Footer, or a hash of these by
        # :default and :first. Each is a part of its own; a given header
        # or footer lends it its content.
        def own_parts(value, klass)
          value = { default: value } unless value.is_a? Hash
          unless value.any? and (value.keys - %i(default first)).empty? and value.values.all? {|v| v.is_a? Proc or v.is_a? klass }
            name = klass.name.split('::').last.downcase
            raise Caracal::Errors::InvalidModelError, "section #{name} takes a block, a #{klass.name} or a hash of these by :default and :first."
          end

          value.to_h do |type, given|
            if given.is_a? Proc
              [type, klass.new(type: type, document: document, section: self, &given)]
            else
              [type, klass.new(type: type, document: document, section: self, source: given)]
            end
          end
        end

      end

    end
  end
end
