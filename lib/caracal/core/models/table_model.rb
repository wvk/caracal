require 'caracal/core/models/base_model'
require 'caracal/core/models/border_model'
require 'caracal/core/models/table_cell_model'
require 'caracal/core/models/table_look_model'
require 'caracal/core/models/concerns/has_background'
require 'caracal/core/models/concerns/has_borders'

module Caracal
  module Core
    module Models

      # This class handles block options passed to the table
      # method.
      class TableModel < BaseModel
        use_prefix :table

        include HasBackground
        include HasBorders

        TABLE_LAYOUTS = %i(fixed autofit)
        TABLE_ALIGNS  = %i(left center right start end)

        has_string_attribute :caption
        has_string_attribute :style, default: 'TableNormal'

        has_symbol_attribute :layout, default: :fixed
        has_symbol_attribute :align, default: :center

        has_integer_attribute :repeat_header, default: 0
        has_integer_attribute :row_band_size, default: 1
        has_integer_attribute :col_band_size, default: 1
        has_integer_attribute :width
        has_integer_attribute :indent

        has_model_attribute :look,
            model: Caracal::Core::Models::TableLookModel,
            default: Caracal::Core::Models::TableLookModel.new

        # accessors
        attr_reader :table_column_widths
        attr_accessor :document

        # initialization
        def initialize(options={}, &block)
          @document             = options.delete :document
          @table_style          = DEFAULT_TABLE_STYLE
          @table_align          = DEFAULT_TABLE_ALIGN
          @table_repeat_header  = DEFAULT_TABLE_REPEAT_HEADER
          @table_row_band_size  = DEFAULT_TABLE_ROW_BAND_SIZE
          @table_col_band_size  = DEFAULT_TABLE_COL_BAND_SIZE
          @table_layout         = DEFAULT_TABLE_LAYOUT
          @table_look           = DEFAULT_TABLE_LOOK
          @table_border         = DEFAULT_TABLE_BORDER

          super options, &block
        end

        #-------------------------------------------------------------
        # Public Methods
        #-------------------------------------------------------------

        #=============== DATA ACCESSORS =======================

        def table_align
          case @table_align
          when :left
            :start
          when :right
            :end
          else
            @table_align
          end
        end

        def cells
          rows.flatten
        end

        def cols
          @cols ||= rows.reduce([]) do |array, row|
            row.each_with_index do |cell, index|
              array[index]  = []  if array[index].nil?
              array[index] << cell
            end
            array
          end
        end

        def rows
          @table_data || [[]]
        end

        # number of grid columns, counting colspans
        def grid_column_count
          rows.map {|row| row.sum(&:grid_span) }.max
        end

        #=============== STYLES ===============================

        # This method sets the width of every wrapped cell to the
        # sum of the grid columns it spans.
        #
        def calculate_width(container_width, container)
          if self.table_width.to_i.zero?
            # column widths covering the whole grid define the table width
            given = table_column_widths.to_a.first grid_column_count
            self.width (given.size == grid_column_count ? given.sum : container_width)
          end

          # now that we know the whole table's width, fix the grid and size the cells to it.
          @grid_column_widths = nil
          @grid_column_widths = grid_column_widths
          each_cell_with_grid_column do |cell, col|
            cell_width = @grid_column_widths[col, cell.grid_span].sum(&:to_i)
            cell.width cell_width
            cell.calculate_width cell_width, self
          end
        end

        # Widths of the table grid columns. Explicit column_widths win.
        # Otherwise explicit cell widths fix the columns they span, a
        # spanning cell's width being spread over its columns, and the
        # rest of the table width is shared by the remaining columns.
        def grid_column_widths
          return @grid_column_widths if @grid_column_widths

          widths = Array.new grid_column_count
          if table_column_widths
            table_column_widths.first(widths.size).each_with_index {|w, i| widths[i] = w }
          else
            sized = []
            each_cell_with_grid_column {|cell, col| sized << [cell, col] if cell.cell_width.to_i > 0 }
            sized.sort_by.with_index {|(cell, _), i| [cell.grid_span, i] }.each do |cell, col|
              span = (col...col + cell.grid_span)
              free = span.select {|i| widths[i].nil? }
              distribute widths, free, cell.cell_width - span.sum {|i| widths[i].to_i } if free.any?
            end
          end

          free = widths.each_index.select {|i| widths[i].nil? }
          distribute widths, free, table_width - widths.sum(&:to_i) if table_width and free.any?
          widths
        end

        # yields each cell with the index of its first grid column
        def each_cell_with_grid_column
          rows.each do |row|
            row.reduce(0) do |col, cell|
              yield cell, col
              col + cell.grid_span
            end
          end
        end

        # This method allows tables to be styled several cells
        # at a time.
        #
        # For example, this would style a header row.
        #
        # docx.table data do |t|
        #   t.cell_style t.rows[0], bgcolor: '3366cc', color: 'ffffff', bold: true
        #   t.cell_style t.rows[2], style: 'MyTableRowStyle'
        # end
        #
        # where 'MyTableRowStyle' is a style with type 'table_row'
        #
        def cell_style(models, options={})
          # styles = merge_named_styles(options)

          [models].flatten.compact.each do |m|
            m.apply_styles options
          end
        end

        #=============== GETTERS ==============================

        def find_style(*args)
          self.document.find_style *args
        end

        #=============== SETTERS ==============================

        # column widths
        def column_widths(value)
          @table_column_widths = value.map &:to_i if value.is_a? Array
        end

        # .data
        def data(value)
          # begin
            @table_data = value.map do |data_row|
              data_row.map do |data_cell|
                cell = case data_cell
                when Caracal::Core::Models::TableCellModel
                  if data_cell.cell_style
                    # data_cell.apply_styles merge_named_styles(style: data_cell.cell_style)
                    # raise "should not happen (yet)"
                    data_cell.apply_styles # style: data_cell.cell_style
                  end
                  data_cell
                when Hash
                  # Caracal::Core::Models::TableCellModel.new merge_named_styles(data_cell)
                  Caracal::Core::Models::TableCellModel.new data_cell
                when Proc
                  Caracal::Core::Models::TableCellModel.new &data_cell
                else
                  Caracal::Core::Models::TableCellModel.new content: data_cell.to_s
                end

                cell.document  = self.document
                cell.table_ref = self
                cell
              end
            end
          #rescue
            #raise Caracal::Errors::InvalidTableDataError, 'Table data must be a two-dimensional array.'
          # end
        end

        #=============== VALIDATION ==============================

        def valid_align?
          validate_inclusion :align, within: TABLE_ALIGNS
        end

        def valid_layout?
          validate_inclusion :layout, within: TABLE_LAYOUTS
        end

        def valid?
          cells.all?{|c| c.nil? or c.is_a? Caracal::Core::Models::TableCellModel } and
              self.valid_bgstyle? and
              self.valid_align? and
              self.valid_layout?
        end

        private
        #
        # # FIXME: needs to be replaced with proper handling of multiple table styles
        # def merge_named_styles(options)
        #   named_style = options.delete :style
        #   if named_style
        #     raise "If you use cell styles, you must create the table using #table" unless @document
        #     ns = find_style named_style
        #     raise "style #{named_style} is not available in document" unless ns
        #     raise "style #{named_style} is a #{ns.style_type} but should be a table, table_cell, or table_row style" unless %i(table table_row table_cell).include?ns.style_type
        #     ns.to_h.merge options.compact
        #   else
        #     options.compact
        #   end
        # end

        # shares total evenly among the given columns, the last one taking the remainder
        def distribute(widths, cols, total)
          share, rest = [total, 0].max.divmod cols.size
          cols.each {|i| widths[i] = share }
          widths[cols.last] += rest
        end

        def option_keys
          k = []
          k << [:data, :align, :width, :style, :layout, :caption, :indent]
          k << HasBackground::ATTRS
          k << HasBorders::ATTRS
          k << [:column_widths]
          k << [:repeat_header, :row_band_size, :col_band_size]
          k.flatten
        end

      end

    end
  end
end
