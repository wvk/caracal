require 'caracal/core/models/frame_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to adding
    # text frames to the document.
    #
    module Frames
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          def frame(options={}, &block)
            model = Caracal::Core::Models::FrameModel.new options.merge(document: @document || self), &block
            if model.valid?
              contents << model
            else
              raise Caracal::Errors::InvalidModelError, "Invalid frame: #{model.errors.map { |e| e[:message] }.join ', '}"
            end
            model
          end

        end
      end
    end

  end
end
