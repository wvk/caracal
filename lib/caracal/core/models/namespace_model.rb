require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # namespace data.
      #
      class NamespaceModel < BaseModel
        use_prefix :namespace

        has_string_attribute :prefix
        has_string_attribute :href

        def ns_hash
          {namespace_prefix => namespace_href}
        end

        def matches?(str)
          namespace_prefix == str.to_s or namespace_prefix == "xmlns:#{str}"
        end

        def valid?
          [:href, :prefix].all? {|a| validate_presence a }
        end

        private

        def option_keys
          [:prefix, :href]
        end
      end

    end
  end
end
