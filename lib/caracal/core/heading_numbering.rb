require 'caracal/core/models/heading_numbering_model'
require 'caracal/errors'

module Caracal
  module Core
    # This module encapsulates all the functionality related to numbering the headings of the document.
    #
    module HeadingNumbering
      def self.included(base)
        base.class_eval do
          def heading_numbering(options={}, &block)
            model = Caracal::Core::Models::HeadingNumberingModel.new options, &block
            if model.valid?
              model.id = next_numbering_id
              @heading_numbering = model
            else
              raise Caracal::Errors::InvalidModelError, model.errors.inspect
            end
            model
          end

          def heading_numbering?
            !!@heading_numbering
          end

          def with_heading_numbering
            yield @heading_numbering if heading_numbering?
          end
        end
      end
    end
  end
end
