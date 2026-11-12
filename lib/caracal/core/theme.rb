require 'caracal/core/models/theme_model'
require 'caracal/errors'

module Caracal
  module Core

    # This module encapsulates all the functionality related to themes.
    # Every document has a theme part; `theme` customizes it.
    module Theme
      def self.included(base)
        # base.class_eval do
        # end
      end

      def theme(&block)
        model = document_theme
        if block
          (block.arity < 1) ? model.instance_exec(&block) : block[model]
        end
        model
      end

      def document_theme
        @theme ||= Models::ThemeModel.new
      end
    end
  end
end
