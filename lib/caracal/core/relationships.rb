require 'caracal/core/models/relationship_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to registering and
    # retrieving relationships.
    #
    module Relationships
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Configuration
          #-------------------------------------------------------------

          attr_reader :relationship_counter


          #-------------------------------------------------------------
          # Class Methods
          #-------------------------------------------------------------

          def self.default_relationships
            [
              { target: 'fontTable.xml',  type: :font      },
              { target: 'numbering.xml',  type: :numbering },
              { target: 'settings.xml',   type: :setting   },
              { target: 'styles.xml',     type: :style     }
            ]
          end


          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          #============== ATTRIBUTES ==========================

          def relationship(options={}, &block)
            id = relationship_counter.to_i + 1
            options = options.merge id: id

            model = Caracal::Core::Models::RelationshipModel.new options, &block
            if model.valid?
              rel = register_relationship model
              @relationship_counter = id if rel.equal? model
            else
              raise Caracal::Errors::InvalidModelError, model.errors.inspect
            end
            rel
          end


          #============== GETTERS =============================

          def relationships
            @relationships ||= []
          end

          def find_relationship(key, type = nil)
            relationships.find { |r| r.matches? key, type }
          end

          def relationships_by_type(type)
            relationships.select { |r| r.relationship_type == type.to_sym }
          end


          #============== REGISTRATION ========================

          def register_relationship(model)
            if (r = find_relationship(model.relationship_key, model.relationship_type))
              # ignore already registered relationships
            else
              relationships << model
              r = model
            end
            r
          end

          def unregister_relationship(target)
            if (r = find_relationship(target))
              relationships.delete(r)
            end
          end

        end
      end
    end

  end
end
