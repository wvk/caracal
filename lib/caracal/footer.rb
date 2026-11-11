require 'caracal/abstract_header_and_footer'

module Caracal
  class Footer < AbstractHeaderAndFooter
    # set by the document at render time, appended after the contents
    attr_accessor :page_number_paragraph

    def relationship_params
      { target: "footer#{index}.xml", type: :footer, owner: self }
    end
  end
end
