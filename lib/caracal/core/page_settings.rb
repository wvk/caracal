require 'caracal/core/models/margin_model'
require 'caracal/core/models/page_size_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to setting the
    # document's size and margins.
    #
    module PageSettings
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Configuration
          #-------------------------------------------------------------

          # accessors
          attr_reader :page_width
          attr_reader :page_orientation
          attr_reader :page_height
          attr_reader :page_margin_top
          attr_reader :page_margin_bottom
          attr_reader :page_margin_left
          attr_reader :page_margin_right
          attr_reader :page_column_count
          attr_reader :page_column_spacing


          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          # This method controls the physical margins of the printed page. Defaults
          # to 1in on each side. Sides not given keep their current value.
          def page_margins(options={}, &block)
            model = Caracal::Core::Models::MarginModel.new options, &block

            if model.valid?
              top    = model.margin_top    || page_margin_top
              bottom = model.margin_bottom || page_margin_bottom
              left   = model.margin_left   || page_margin_left
              right  = model.margin_right  || page_margin_right
              validate_page_fit! page_width, page_height, top + bottom, left + right

              @page_margin_top    = top
              @page_margin_bottom = bottom
              @page_margin_left   = left
              @page_margin_right  = right
            else
              raise Caracal::Errors::InvalidModelError, 'page_margins method requires non-zero :top, :bottom, :left, and :right options.'
            end
          end

          # This method controls the physical width and height of the printed page. Defaults
          # to US Letter portrait size. Options not given keep their current value.
          def page_size(options={}, &block)
            current = { width: page_width, height: page_height, orientation: page_orientation }.compact
            model   = Caracal::Core::Models::PageSizeModel.new current.merge(options), &block

            if model.valid?
              validate_page_fit! model.page_width, model.page_height,
                  page_margin_top.to_i + page_margin_bottom.to_i,
                  page_margin_left.to_i + page_margin_right.to_i

              @page_width       = model.page_width
              @page_height      = model.page_height
              @page_orientation = model.page_orientation
            else
              raise Caracal::Errors::InvalidModelError, 'page_size method requires non-zero :width and :height options.'
            end
          end

          # Sets the text in this many columns, `spacing` twips apart.
          def page_columns(count, spacing: 720)
            unless count.is_a? Integer and count.between?(1, 45) and spacing.is_a? Integer and spacing >= 0
              raise Caracal::Errors::InvalidModelError, 'page_columns takes a column count of 1 to 45 and a spacing of 0 or more twips.'
            end
            unless (count - 1) * spacing < page_width - page_margin_left - page_margin_right
              raise Caracal::Errors::InvalidModelError, 'page columns must fit between the page margins.'
            end

            @page_column_count   = count
            @page_column_spacing = spacing
          end

          # The width of a line of text: the space between the page
          # margins, or one column of it.
          def page_content_width
            width = page_width - page_margin_left - page_margin_right
            count = page_column_count || 1
            (width - (count - 1) * page_column_spacing.to_i) / count
          end

          private

          def validate_page_fit!(width, height, vertical_margins, horizontal_margins)
            unless vertical_margins < height and horizontal_margins < width
              raise Caracal::Errors::InvalidModelError, 'page margins must be smaller than the page size.'
            end
          end

        end
      end
    end

  end
end
