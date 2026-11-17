require 'caracal/core/models/rule_model'
require 'caracal/core/models/section_model'
require 'caracal/errors'


module Caracal
  module Core

    # This module encapsulates all the functionality related to dividing
    # the document into sections.
    #
    module Sections
      def self.included(base)
        base.class_eval do

          #-------------------------------------------------------------
          # Configuration
          #-------------------------------------------------------------

          # the section whose block is being evaluated
          attr_reader :current_section


          #-------------------------------------------------------------
          # Public Methods
          #-------------------------------------------------------------

          # The content added in the block forms a section with the given
          # settings. The content before it stays in the section before;
          # the content after it continues in a section with the
          # document's settings.
          def section(options = {}, &block)
            raise Caracal::Errors::InvalidModelError, 'sections cannot be nested.' if current_section

            model = Caracal::Core::Models::SectionModel.new(options || {}, document: self)
            start = contents.size
            contents << Caracal::Core::Models::SectionModel.new(document: self) unless contents.empty? or contents.last.is_a? Caracal::Core::Models::SectionModel
            opened = contents.size

            begin
              @current_section = model
              (block.arity < 1) ? instance_exec(&block) : block[self] if block
            ensure
              @current_section = nil
            end

            if contents.size == opened # an empty section leaves the document as it was
              contents.pop contents.size - start
            else
              contents[opened..].grep(Caracal::Core::Models::RuleModel).each do |rule|
                rule.calculate_width model.page_content_width, model if rule.rule_container_width.nil?
              end
              contents << model
            end
            model
          end

          # The document's sections in order: one for each section model in
          # the contents, and the last one, with the document's settings,
          # unless the contents end with a section.
          def sections
            list = contents.grep Caracal::Core::Models::SectionModel
            list << (@document_section ||= Caracal::Core::Models::SectionModel.new(document: self)) unless contents.last.is_a? Caracal::Core::Models::SectionModel
            list
          end

        end
        base.prepend PageContentWidth
      end

      # Tables added in a section's block span the section's text width.
      module PageContentWidth
        def page_content_width
          current_section ? current_section.page_content_width : super
        end
      end
    end

  end
end
