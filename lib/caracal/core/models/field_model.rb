module Caracal
  module Core
    module Models

      # This class encapsulates the logic needed to store and manipulate
      # fields.
      class FieldModel < TextModel
        use_prefix :field

        has_string_attribute :name

        #========== VALIDATION ============================

        def valid?
          validate_presence :name
        end

        private

        def option_keys
          super + [:name]
        end

        #def method_missing(method, *args, &block)
          # I'm on the fence with respect to this implementation. We're ignoring
          # :method_missing errors to allow syntax flexibility for paragraph-type
          # models.  The issue is the syntax format of those models--the way we pass
          # the content value as a special argument--coupled with the model's
          # ability to accept nested instructions.
          #
          # By ignoring method missing errors here, we can pass the entire paragraph
          # block in the initial, built-in call to :text.
        #end
      end

    end
  end
end
