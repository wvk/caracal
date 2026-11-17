require 'caracal/core/models/page_break_model'


module Caracal
  module Core
    module Models

      # A break to the next page column (see `page_columns`). Like a page
      # break, it is wrapped in a paragraph at the document level.
      class ColumnBreakModel < PageBreakModel
      end

    end
  end
end
