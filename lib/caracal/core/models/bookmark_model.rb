require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # bookmarks.
      class BookmarkModel < BaseModel
        use_prefix :bookmark

        has_boolean_attribute :start
        has_string_attribute  :id # pairs start and end; rendered as a unique integer w:id
        has_string_attribute :name

        #========== GETTERS ===============================

        def run_attributes
          {
            start: bookmark_start,
            id:    bookmark_id,
            name:  bookmark_name
          }
        end
        #========== STATE HELPERS =========================

        def start?
          !!bookmark_start
        end

        #========== VALIDATION ============================

        def valid?
          start? ? !bookmark_name.to_s.strip.empty? : true
        end

        private

        def option_keys
          [:id, :name, :start]
        end

      end
    end
  end
end
