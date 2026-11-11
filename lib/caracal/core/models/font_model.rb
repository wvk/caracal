require 'caracal/core/models/base_model'
require 'caracal/errors'
require 'caracal/font_file'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # font data.
      #
      # A font can optionally embed its font files into the document:
      #
      #   docx.font name: 'Source Serif Pro', regular: 'fonts/SourceSerifPro-Regular.ttf', bold: 'fonts/SourceSerifPro-Bold.ttf'
      #
      # Each style (regular, bold, italic, bold_italic) accepts a file path or an IO.
      # Embedded fonts are obfuscated as required by ECMA-376 §17.8.1; `obfuscate false`
      # embeds them as plain TrueType files instead.
      class FontModel < BaseModel
        use_prefix :font

        STYLES = %i(regular bold italic bold_italic)

        # One embedded font file. index is assigned by the document while rendering.
        EmbeddedFont = Struct.new :font, :style, :font_file, :key, :index do
          def element_name
            "embed#{style.to_s.split('_').map(&:capitalize).join}"
          end

          def obfuscated?
            font.font_obfuscate
          end

          def font_key
            obfuscated? ? key : FontFile::ZERO_KEY
          end

          def rel_id
            "rId#{index}"
          end

          def target
            "fonts/font#{index}.#{obfuscated? ? 'odttf' : 'ttf'}"
          end

          def content
            obfuscated? ? FontFile.obfuscate(font_file.data, key) : font_file.data
          end
        end

        has_string_attribute  :name
        has_boolean_attribute :obfuscate, default: true

        def initialize(options={}, &block)
          @font_obfuscate = DEFAULT_FONT_OBFUSCATE
          @embedded_fonts = {}
          super options, &block
        end

        #=============== SETTERS ==============================

        STYLES.each do |style|
          define_method style do |source|
            font_file = FontFile.new(read_font_source(source)).check_embeddable!
            @embedded_fonts[style] = EmbeddedFont.new self, style, font_file, FontFile.generate_key
          end
        end

        #=============== GETTERS ==============================

        # embedded font files in schema order: regular, bold, italic, bold italic
        def embedded_fonts
          STYLES.map {|style| @embedded_fonts[style] }.compact
        end

        #=============== STATE ================================

        def matches?(str)
          font_name.to_s.downcase == str.to_s.downcase
        end

        def embedded?
          @embedded_fonts.any?
        end

        #=============== VALIDATION ===========================

        def valid?
          validate_presence :name
        end

        private

        def option_keys
          [:name, :obfuscate] + STYLES
        end

        def read_font_source(source)
          if source.respond_to? :read
            source.read
          else
            File.binread source.to_s
          end
        rescue SystemCallError => e
          raise Caracal::Errors::InvalidFontError, "cannot read font file #{source}: #{e.message}"
        end

      end
    end
  end
end
