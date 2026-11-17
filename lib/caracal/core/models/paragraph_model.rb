require 'caracal/core/models/base_model'
require 'caracal/core/models/bookmark_model'
require 'caracal/core/models/column_break_model'
require 'caracal/core/models/image_model'
require 'caracal/core/models/link_model'
require 'caracal/core/models/text_model'
require 'caracal/core/models/theme_color_model'
require 'caracal/core/models/concerns/has_margins'
require 'caracal/core/models/concerns/has_run_attributes'
require 'caracal/errors'
require 'ostruct'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # paragraph data.
      class ParagraphModel < BaseModel
        use_prefix :paragraph

        include HasRunAttributes
        extend HasMargins

        # ST_TabJc, including the transitional left and right
        TAB_ALIGNS = %i(clear start center end decimal bar num left right)

        has_margins

        has_string_attribute :style

        has_symbol_attribute :align
        has_symbol_attribute :line_rule

        has_integer_attribute :line

        has_boolean_attribute :keep_next
        has_boolean_attribute :keep_lines
        has_boolean_attribute :widow_control
        has_boolean_attribute :hide_mark
        has_boolean_attribute :bidi # right-to-left paragraph

        attr_reader :paragraph_tabs

        def initialize(options={}, &block)
          o = options.dup
          content = o.delete(:content) { '' }
          super o, &block

          # if there's content from the block, do not append an empty string content
          # otherwise make sure there is at least one (potentially empty) run
          if self.runs.none? or not content.to_s.strip.empty?
            text content, self.run_attributes
            content_added
          end
        end


        #--------------------------------------------------
        # Public Instance Methods
        #--------------------------------------------------

        #========== GETTERS ===============================

        def runs
          @runs ||= []
        end

        # The text of the runs, as Word shows them: one after the other.
        def plain_text
          runs.collect { |run| (run.text_content if run.respond_to? :text_content).to_s }.join.strip
        end

        def spacing_options
          {
            top:    self.paragraph_top,
            bottom: self.paragraph_bottom,
            line:   self.paragraph_line,
            line_rule: self.paragraph_line_rule
          }
        end

        def paragraph_attributes
          {
            line:          self.paragraph_line,
            line_rule:     self.paragraph_line_rule,
            align:         self.paragraph_align,
            keep_next:     self.paragraph_keep_next,
            keep_lines:    self.paragraph_keep_lines,
            widow_control: self.paragraph_widow_control,
            bidi:          self.paragraph_bidi
          }.compact
        end

        #========== SETTERS ===============================

        # Sets the indent of one or both sides, like `left` and `right`:
        # `indent left: 720`.
        def indent(hash)
          unless hash.is_a? Hash and hash.any? and hash.all? {|side, value| %i(left right).include? side and value.is_a? Integer }
            raise Caracal::Errors::InvalidModelError, 'the indent setter requires a hash like left: X or right: Y.'
          end

          hash.each {|side, value| send side, value }
        end

        def tabs(values)
          @paragraph_tabs = values
        end

        #========== SUB-METHODS ===========================

        def field(*args, &block)
          options = self.run_attributes.to_h.except(:hide_mark)
          options.merge! Caracal::Utilities.extract_options!(args).dup
          options.merge! name: args.first if args.first

          model = Caracal::Core::Models::FieldModel.new options, &block
          if model.valid?
            runs << model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        # .bookmarks
        def bookmark_start(*args, &block)
          options = Caracal::Utilities.extract_options!(args).dup
          options.merge! start: true

          model = Caracal::Core::Models::BookmarkModel.new options, &block
          if model.valid?
            runs << model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        def bookmark_end(*args, &block)
          options = Caracal::Utilities.extract_options!(args).dup
          options.merge! start: false

          model = Caracal::Core::Models::BookmarkModel.new options, &block
          if model.valid?
            runs << model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        # .br
        def br
          model = Caracal::Core::Models::LineBreakModel.new
          runs << model
          model
        end

        # .footnote
        # Its number in the text takes this paragraph's formatting; its
        # text takes the FootnoteText style.
        def footnote(*args, &block)
          options = Caracal::Utilities.extract_options!(args).dup
          options.merge! content: args.first if args.first

          model = Caracal::Core::Models::FootnoteModel.new options, &block
          if model.valid?
            runs << Caracal::Core::Models::FootnoteReferenceModel.new(self.run_attributes.to_h.merge(footnote: model))
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        # .img
        # An image within the line of text. It follows the paragraph's
        # alignment, so align positions anchored images only.
        def img(*args, &block)
          options = Caracal::Utilities.extract_options!(args)
          options.merge! url: args.first if args.first

          model = Caracal::Core::Models::ImageModel.new options, &block
          unless model.valid?
            raise Caracal::Errors::InvalidModelError, "Invalid image: #{model.errors.map { |e| e[:message] }.join ', '}"
          end
          if model.own_align? and not model.image_anchor
            raise Caracal::Errors::InvalidModelError, 'An image within a paragraph follows the paragraph\'s alignment; align positions anchored images only.'
          end

          runs << model
          model
        end

        # .link
        def link(*args, &block)
          options = self.run_attributes.to_h
          options.merge! Caracal::Utilities.extract_options!(args).dup
          options.merge! content: args[0] if args[0]
          options.merge! href:    args[1] if args[1]

          model = Caracal::Core::Models::LinkModel.new(options.except(:hide_mark), &block)
          if model.valid?
            runs << model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        # .page
        def page
          model = Caracal::Core::Models::PageBreakModel.new wrap: false
          runs << model
          model
        end

        def column_break
          model = Caracal::Core::Models::ColumnBreakModel.new wrap: false
          runs << model
          model
        end

        # .text
        def text(*args, &block)
          options = self.run_attributes.to_h.except(:hide_mark)
          options.merge! Caracal::Utilities.extract_options!(args)
          options.merge! content: args.first if args.first

          model = Caracal::Core::Models::TextModel.new options, &block
          if model.valid?
            runs << model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        #========== STATE =================================

        def empty?
          runs.size.zero? || plain_text.length.zero?
        end

        def apply_styles(opts={}, reverse: false)
          options = opts.dup
          pa = self.paragraph_attributes
          options.each do |k, v|
            if self.respond_to? k and (reverse or not pa[k])
              self.send k, v
              # options.delete k unless HasRunAttributes::ATTRS.include? k
            end
          end

          self.runs.each do |run|
            run.apply_styles options
          end
        end

        #========== VALIDATION ============================

        def valid?
          runs.any? and
              validate_inclusion :line_rule, within: StyleModel::LINE_RULES.keys and
              self.valid_tabs? and
              self.valid_bgstyle? and
              self.valid_run_attributes?
        end

        # a tab stop's val is an ST_TabJc value; without one it is start
        def valid_tabs?
          vals    = Array(paragraph_tabs).grep(Hash).filter_map {|t| t[:val] }
          invalid = vals.reject {|v| TAB_ALIGNS.include? v.to_s.to_sym }
          invalid.each {|v| errors << {message: "#{v.inspect} is not in #{TAB_ALIGNS.inspect}", model: self, attribute: :tabs, value: v} }
          invalid.empty?
        end

        def self.option_keys
          %i[content style align tabs top bottom line line_rule keep_next keep_lines widow_control hide_mark bidi] +
              HasMargins::ATTRS +
              HasRunAttributes::ATTRS
        end

        private

        # The content run is appended after the block's runs, so the block's
        # run options apply to it, but it is the paragraph's own text, so it
        # leads the paragraph.
        def content_added
          runs.unshift runs.pop
        end

        def option_keys
          self.class.option_keys
        end

      end
    end
  end
end
