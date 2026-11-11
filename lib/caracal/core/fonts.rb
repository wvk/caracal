require 'caracal/core/models/font_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to registering
    # fonts.
    #
    module Fonts
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Class Methods
          #-------------------------------------------------------------

          def self.default_fonts
            [
              { name: 'Arial' },
              { name: 'Trebuchet MS' }
            ]
          end

          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          #============== ATTRIBUTES ==========================

          def font(options={}, &block)
            model = Caracal::Core::Models::FontModel.new options, &block

            if model.valid?
              register_font model
            else
              raise Caracal::Errors::InvalidModelError, 'font must specify the :name attribute.'
            end
            model
          end

          #============== GETTERS =============================

          def fonts
            @fonts ||= []
          end

          def find_font(name)
            fonts.find { |f| f.matches? name }
          end

          # all embedded font files of all fonts, numbered consecutively. The number determines
          # both the part name (word/fonts/fontN.odttf) and the relationship id within the font table.
          def embedded_fonts
            fonts.flat_map(&:embedded_fonts).each.with_index(1) {|embedded, index| embedded.index = index }
          end

          #============== REGISTRATION ========================

          def register_font(model)
            unregister_font model.font_name
            fonts << model
            model
          end

          def unregister_font(name)
            f = find_font name
            fonts.delete f if f
          end

        end
      end
    end

  end
end
