require 'caracal/core/models/base_model'
require 'caracal/core/models/image_model'
require 'caracal/core/models/paragraph_model'
require 'caracal/core/models/table_model'
require 'caracal/core/lists'
require 'caracal/core/tables'
require 'caracal/core/text'


module Caracal
  module Core
    module Models

      # This class handles block options passed to the frame method: a
      # text box at a fixed position, placed like an anchored image. It
      # holds paragraphs, headings, lists and tables.
      #
      class FrameModel < BaseModel
        use_prefix :frame

        include Caracal::Core::Lists
        include Caracal::Core::Tables
        include Caracal::Core::Text

        ALIGNS = [:left, :center, :right]

        has_integer_attribute :width                          # units in twips.
        has_integer_attribute :height                         # units in twips.
        has_integer_attribute :x                              # units in twips.
        has_integer_attribute :y                              # units in twips.
        has_symbol_attribute :align, default: :left           # without x
        has_symbol_attribute :relative_to, default: :page
        has_symbol_attribute :relative_to_x                   # defaults to relative_to
        has_symbol_attribute :relative_to_y                   # defaults to relative_to
        has_symbol_attribute :wrap, default: :top_and_bottom

        attr_reader :document

        # initialization
        def initialize(options={}, &block)
          options = options.dup
          @document          = options.delete :document
          @frame_align       = DEFAULT_FRAME_ALIGN
          @frame_relative_to = DEFAULT_FRAME_RELATIVE_TO
          @frame_wrap        = DEFAULT_FRAME_WRAP

          super options, &block

          # like a table cell, a frame ends in a paragraph, here 1pt high.
          unless contents.empty? or contents.last.is_a? ParagraphModel
            contents << ParagraphModel.new(content: '', size: 2, top: 0, bottom: 0, line: 20, line_rule: :exact)
          end

          # tables span the frame's width
          if frame_width.to_i > 0
            contents.grep(TableModel).each {|table| table.calculate_width frame_width, self }
          end
        end

        #=============== DATA ACCESSORS =======================

        def contents
          @contents ||= []
        end

        #=============== GETTERS ==============================

        [:width, :height, :x, :y].each do |m|
          define_method "formatted_#{m}" do
            value = send("frame_#{m}")
            value * 635 unless value.nil? # twips to EMUs
          end
        end

        #=============== VALIDATION ==============================

        def valid?
          [:width, :height].all? { |a| validate_size a, at_least: 0 } and
            [:relative_to, :relative_to_x, :relative_to_y].all? { |a| validate_inclusion a, within: ImageModel::RELATIVE_TOS } and
            validate_inclusion(:wrap, within: ImageModel::WRAPS, allow_nil: false) and
            validate_inclusion(:align, within: ALIGNS, allow_nil: false) and
            validate('must contain a paragraph, list or table') { contents.any? }
        end

        private

        def option_keys
          [:width, :height, :x, :y, :align, :relative_to, :relative_to_x, :relative_to_y, :wrap]
        end

      end

    end
  end
end
