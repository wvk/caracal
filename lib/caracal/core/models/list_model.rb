require 'caracal/core/models/base_model'
require 'caracal/core/models/list_item_model'
require 'caracal/errors'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # list data.
      #
      class ListModel < BaseModel
        attr_accessor :numbering_id # identifies the numbering of this list's items. Set during document rendering.

        use_prefix :list

        has_symbol_attribute :type, default: :unordered
        has_integer_attribute :level, default: 0

        # initialization
        def initialize(options={}, &block)
          @list_type  = DEFAULT_LIST_TYPE
          @list_level = DEFAULT_LIST_LEVEL

          super options, &block
        end

        #=============== GETTERS ==============================

        # This method returns only those items owned directly
        # by this list.
        def items
          @items ||= []
        end

        # This method returns a hash of the numberings used by this
        # list's tree, set by assign_numbering. The keys are numbering
        # ids and the values map each level to its list type.
        def numberings
          @numberings || {}
        end

        # This method gives this list and its nested lists their numbering
        # ids, taking new ids from the block. A nested list shares its
        # parent's numbering unless that uses another list type at its
        # level; then it starts a new numbering, so that its markers match
        # its type.
        def assign_numbering(numberings = (@numberings = {}), parent_id = nil, &next_id)
          inherited = numberings[parent_id]
          if inherited.nil? or not [nil, list_type].include? inherited[list_level]
            self.numbering_id = next_id.call
            numberings[numbering_id] = (inherited || {}).select {|level, _| level < list_level }
          else
            self.numbering_id = parent_id
          end
          numberings[numbering_id][list_level] = list_type

          items.each {|item| item.nested_list&.assign_numbering numberings, numbering_id, &next_id }
        end

        # This method returns a flattened array containing every
        # item within this list's tree.
        def recursive_items
          items.map do |model|
            if model.nested_list.nil?
              model
            else
              [model, model.nested_list.recursive_items]
            end
          end.flatten
        end

        #=============== SUB-METHODS ===========================

        # .li
        def li(*args, &block)
          options = Caracal::Utilities.extract_options! args
          options.merge! content: args.first if args.first
          options.merge! type: list_type, level: list_level

          model = Caracal::Core::Models::ListItemModel.new options, &block
          if model.valid?
            items << model
          else
            raise Caracal::Errors::InvalidModelError, 'List item must have at least one run.'
          end
          model
        end


        def apply_styles(opts={}, reverse: false)
          self.items.each do |item|
            item.apply_styles opts, reverse: reverse
          end
        end

        #=============== VALIDATION ===========================

        def valid?
          [:type, :level].all? {|a| validate_presence a } and not items.empty?
        end

        private

        def option_keys
          [:type, :level]
        end

      end
    end
  end
end
