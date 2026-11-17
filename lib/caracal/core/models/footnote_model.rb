require 'caracal/core/models/paragraph_model'
require 'caracal/core/models/footnote_reference_model'
require 'caracal/core/models/text_model'
require 'caracal/errors'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # footnote data. A footnote is a paragraph at the foot of the page,
      # in the FootnoteText style, that opens with its number.
      class FootnoteModel < ParagraphModel
        STYLE = 'FootnoteText'

        # initialization
        def initialize(options={}, &block)
          super options, &block

          @paragraph_style ||= STYLE

          attrs = run_attributes.to_h.except(:hide_mark)
          runs.unshift FootnoteReferenceModel.new(attrs), TextModel.new(attrs.merge(content: ' '))
        end

        #========== SUB-METHODS ===========================

        def footnote(*args, &block)
          raise Caracal::Errors::InvalidModelError, 'footnotes cannot contain footnotes.'
        end

      end
    end
  end
end
