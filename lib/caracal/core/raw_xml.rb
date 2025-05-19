require 'caracal/core/models/raw_xml_model'
require 'caracal/errors'


module Caracal
  module Core

    module RawXml
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          #============== PARAGRAPHS ==========================

          def raw_xml(str, &block)
            model = Caracal::Core::Models::RawXmlModel.new str, &block
            contents << model
            model
          end

        end
      end
    end

  end
end
