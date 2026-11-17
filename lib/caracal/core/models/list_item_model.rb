require 'caracal/core/models/list_model'
require 'caracal/core/models/paragraph_model'
require 'caracal/errors'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # list item data.
      class ListItemModel < ParagraphModel
        use_prefix :list_item

        has_integer_attribute :level
        has_symbol_attribute :type

        attr_writer :continuation

        # readers (create aliases for superclass methods to conform
        # to expected naming convention.)
        (ParagraphModel::option_keys - %i(content)).each do |attr|
          alias_method :"list_item_#{attr}", :"paragraph_#{attr}"
        end

        #=============== NESTED LISTS =========================

        # The nested lists in the order they were added, each with the
        # number of runs that came before it, so text after a nested list
        # renders after it.
        def nested_lists
          @nested_lists ||= []
        end

        def nested_list
          nested_lists.last&.last
        end

        def nested_list=(model)
          nested_lists << [runs.size, model]
        end

        # Whether this is text following a nested list, which renders as an
        # unnumbered paragraph aligned with the item's text.
        def continuation?
          !!@continuation
        end

        # This item split at its nested lists, in document order: the
        # item's text up to its first nested list, that list, the text
        # that follows it, and so on.
        def parts
          return [self] if nested_lists.empty?

          parts = []
          start = 0
          nested_lists.each do |(index, list)|
            parts << segment(start...index, parts.any?) if parts.empty? or index > start
            parts << list
            start = index
          end
          parts << segment(start...runs.size, true) if runs.size > start
          parts
        end

        # This item and everything nested in it, in document order.
        def recursive_items
          return [self] if nested_lists.empty?

          parts.flat_map(&:recursive_items)
        end

        #=============== SUB-METHODS ===========================

        def ol(options={}, &block)
          options.merge! type: :ordered, level: list_item_level + 1

          model = Caracal::Core::Models::ListModel.new(options, &block)
          if model.valid?
            self.nested_list = model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        def ul(options={}, &block)
          options.merge! type: :unordered, level: list_item_level + 1

          model = Caracal::Core::Models::ListModel.new(options, &block)
          if model.valid?
            self.nested_list = model
          else
            raise Caracal::Errors::InvalidModelError, model.errors.inspect
          end
          model
        end

        #=============== VALIDATION ===========================

        def valid?
          super and [:type, :level].all? {|a| validate_presence a } and not runs.empty?
        end

        def apply_styles(opts={}, reverse: false)
          options = opts.dup
          options.each do |k, v|
            if self.respond_to? k
              if not reverse or self.send("list_item_#{k}").nil?
                send k, v
              end
              # options.delete k
            end
          end

          self.runs.each do |run|
            run.apply_styles options
          end

          super options, reverse: reverse
        end

        private

        # The content run is appended after the block's runs, but it is the
        # item's own text, so it leads the item, before any nested list.
        def content_added
          runs.unshift runs.pop
          nested_lists.each {|pair| pair[0] += 1 }
        end

        # A copy of this item holding only the given runs.
        def segment(range, continuation)
          copy = dup
          copy.instance_variable_set :@runs, runs[range]
          copy.instance_variable_set :@nested_lists, []
          copy.continuation = continuation
          copy
        end

        def option_keys
          super + %i[type level]
        end

      end
    end
  end
end
