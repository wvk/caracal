require 'caracal/core/models/text_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # a footnote's number: in the text, the reference to its footnote;
      # at the start of the footnote, the footnote's own mark. Both use the
      # FootnoteReference character style.
      class FootnoteReferenceModel < TextModel
        STYLE = 'FootnoteReference'

        # the footnote referred to; nil for the mark opening a footnote
        attr_reader :footnote

        # initialization
        def initialize(options={}, &block)
          o = options.dup
          @footnote = o.delete :footnote
          super o.except(:vertical_align, :hide_mark).merge(style: STYLE), &block
        end

        #========== STATE =================================

        def mark?
          footnote.nil?
        end

        # the number keeps its style, which raises it
        def apply_styles(opts={}, reverse: false)
          super opts.reject {|k, _| %i(style vertical_align).include? k.to_sym }, reverse: reverse
        end

        #========== VALIDATION ============================

        def valid?
          self.valid_run_attributes?
        end

      end

    end
  end
end
