require 'caracal/core/relationships'

module Caracal
  # The footnotes part, word/footnotes.xml. Like a header or footer it has
  # its own relationships, so links in footnotes point into
  # word/_rels/footnotes.xml.rels.
  class Footnotes
    include Caracal::Core::Relationships

    attr_reader :document

    def initialize(document:)
      @document = document
    end

    # The footnotes in the order they are numbered.
    def contents
      @contents ||= []
    end

    # Returns the footnote's id, numbering it first if necessary. Ids
    # count from 1; Word's separators take -1 and 0.
    def id_for(model)
      ids[model] ||= (contents << model).size
    end

    # Forgets the numbering, so each rendering numbers afresh.
    def clear
      contents.clear
      ids.clear
    end

    def relationship_params
      { target: 'footnotes.xml', type: :footnotes, owner: self }
    end

    # The footnotes declare the document's namespaces and share its ids.
    def namespaces
      document.namespaces
    end

    def ignorables
      document.ignorables
    end

    def next_drawing_id
      document.next_drawing_id
    end

    def next_bookmark_id
      document.next_bookmark_id
    end

    def document_theme
      document.document_theme
    end

    private

    def ids
      @ids ||= {}
    end
  end
end
