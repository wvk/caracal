require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models
      # This class encapsulates the numbering scheme of the heading styles Heading1 to Heading6.
      # Each heading level maps to one level of a single multi-level numbering definition.
      #
      #   heading_numbering do
      #     h1 fmt: 'decimal', text: '%1.'
      #     h2 fmt: 'decimal', text: '%1.%2'
      #   end
      #
      # or, equivalently:
      #
      #   heading_numbering h1: { fmt: 'decimal', text: '%1.' }, h2: { fmt: 'decimal', text: '%1.%2' }
      #
      # text references the counters of the current and all higher levels as %1 (h1) to %6 (h6).
      # Levels left undefined stay unnumbered.
      class HeadingNumberingModel < BaseModel
        use_prefix :heading_numbering

        attr_reader   :heading_numberings
        attr_accessor :id # identifies the numbering definition. Set during document rendering.

        has_string_attribute :name, default: 'Caracal heading numbering'

        LEVELS   = %i(h1 h2 h3 h4 h5 h6)
        FORMATS  = %w(decimal decimalZero lowerLetter upperLetter lowerRoman upperRoman ordinal none)
        SUFFIXES = %w(tab space nothing)

        def initialize(options={}, &block)
          @heading_numbering_name = DEFAULT_HEADING_NUMBERING_NAME
          @heading_numberings = LEVELS.each_with_index.to_h do |level, ilvl|
            [level, { style_id: "Heading#{ilvl + 1}", ilvl: ilvl, fmt: 'none', lvl_text: '', suff: 'nothing' }]
          end
          @unknown_levels = options.keys - LEVELS

          options.slice(*LEVELS).each {|level, opts| send level, **opts }
          super({}, &block)
        end

        LEVELS.each do |level|
          define_method level do |fmt: 'decimal', text: '', suff: 'space'|
            heading_numberings[level].merge! fmt: fmt.to_s, lvl_text: text.to_s, suff: suff.to_s
          end
        end

        # zero-based numbering level of the given heading style id, e.g. 1 for 'Heading2'
        def ilvl_for(style_id)
          numbering = heading_numberings.values.find {|num| num[:style_id] == style_id }
          numbering[:ilvl] if numbering
        end

        def to_h
          heading_numberings
        end

        def valid?
          validate("unknown heading levels #{@unknown_levels.inspect}, must be within #{LEVELS.inspect}") { @unknown_levels.empty? } and
            validate("fmt must be one of #{FORMATS.inspect}") { heading_numberings.values.all? {|num| FORMATS.include? num[:fmt] } } and
            validate("suff must be one of #{SUFFIXES.inspect}") { heading_numberings.values.all? {|num| SUFFIXES.include? num[:suff] } }
        end
      end
    end
  end
end
