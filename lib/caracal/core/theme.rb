require 'caracal/core/models/theme_model'
require 'caracal/errors'

module Caracal
  module Core

    # This module encapsulates all the functionality related to themes.
    module Theme
      def self.included(base)
        # base.class_eval do
        # end
      end

      def theme(&block)
        @theme = Models::ThemeModel.new &block
        relationship owner: @theme, type: :theme, target: 'theme'
        @theme
      end

      def use_theme?
        not @theme.nil?
      end

      def document_theme
        @theme
      end
    end
  end
end
