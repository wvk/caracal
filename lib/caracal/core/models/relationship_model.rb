require 'digest'
require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # relationship data.
      #
      class RelationshipModel < BaseModel
        use_prefix :relationship

        #-------------------------------------------------------------
        # Configuration
        #-------------------------------------------------------------

        # constants
        TYPE_MAP = {
          font:       'http://schemas.openxmlformats.org/officeDocument/2006/relationships/fontTable',
          header:     'http://schemas.openxmlformats.org/officeDocument/2006/relationships/header',
          footer:     'http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer',
          image:      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image',
          link:       'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink',
          numbering:  'http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering',
          setting:    'http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings',
          style:      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles',
          theme:      'http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme'
        }

        has_integer_attribute :id

        has_string_attribute :target
        has_string_attribute :data

        has_symbol_attribute :type, downcase: true

        attr_reader :owner

        #-------------------------------------------------------------
        # Public Instance Methods
        #-------------------------------------------------------------

        #=================== GETTERS =============================

        # Relationships with the same key share one part; embedded data is
        # part of the key, so placeholder targets with different data stay apart.
        def relationship_key
          key = relationship_target.to_s.downcase
          key += "##{Digest::SHA256.hexdigest relationship_data}" unless relationship_data.to_s.empty?
          key
        end

        def formatted_id
          "rId#{relationship_id}"
        end

        def formatted_target
          case relationship_type
          when :image
            ext = relationship_target.to_s.split('.').last
            ext = ext.split('?').first
            # named by key, so parts with their own ids (headers, footers) share one media folder
            "media/image-#{Digest::SHA256.hexdigest(relationship_key)[0, 16]}.#{ext}"
          when :theme
            "theme/theme1.xml"
          else
            relationship_target
          end
        end

        def formatted_type
          TYPE_MAP.fetch(relationship_type)
        end

        #=================== SETTERS =============================

        def target(value)
          @relationship_target = value.to_s
        end

        #=================== STATE ===============================

        def matches?(str, type = nil)
          relationship_key == str.to_s.downcase and (type.nil? or relationship_type == type.to_sym)
        end

        def target_mode?
          relationship_type == :link
        end

        def owner(owner=nil)
          if owner.nil?
            @relationship_owner
          else
            @relationship_owner = owner
          end
        end

        #=============== VALIDATION ===========================

        def valid?
          [:id, :target, :type].all? {|a| validate_presence a } and
              validate_inclusion :type, within: TYPE_MAP.keys
        end

        #-------------------------------------------------------------
        # Private Instance Methods
        #-------------------------------------------------------------
        private

        def option_keys
          [:id, :type, :target, :data, :owner]
        end
      end

    end
  end
end
