require 'caracal/core/models/table_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to adding tables
    # to the document.
    module Tables
      def self.included(base)
        base.class_eval do

          def table(*args, &block)
            options = Caracal::Utilities.extract_options! args
            options.merge! data: args.first if args.first

            table_model = Caracal::Core::Models::TableModel.new options.merge(document: @document || self), &block

            if self.respond_to? :page_width
              table_model.calculate_width self.page_content_width, self
            end

            if table_model.valid?
              contents << table_model
            else
              raise Caracal::Errors::InvalidModelError, table_model.errors.inspect
            end

            table_model
          end

        end
      end
    end

  end
end
