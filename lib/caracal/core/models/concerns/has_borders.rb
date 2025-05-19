require 'caracal/core/models/border_model'

module Caracal
  module Core
    module Models
      module HasBorders
        ATTRS = %i(border) + BorderModel::TYPES.map{|dir| :"border_#{dir}" } + BorderModel::ATTRS.map{|attr| :"border_#{attr}" }

        def self.included(base)
          # default border for all edges
          base.has_model_attribute :border,
              model: Caracal::Core::Models::BorderModel
              # default: Caracal::Core::Models::BorderModel.new # really have a default here?

          border_writer_name = 'border'
          border_reader_name = "#{base.attr_prefix}_border" # e.g. table_border

          # writer for default border model (border)
          base.define_method border_writer_name do |options = {}, &block|
            instance_variable_set "@#{border_reader_name}", Caracal::Core::Models::BorderModel.new(options, &block)
          end

          BorderModel::ATTRS.each do |attr|
            bdr_attr         = :"border_#{attr}"                # e.g. self.border.border_color
            attr_writer_name = :"#{border_writer_name}_#{attr}" # e.g. self.border_color
            attr_reader_name = :"#{border_reader_name}_#{attr}" # e.g. self.table_border_color
            # ATTRS << bdr_attr

            define_method attr_writer_name do |value, &block|
              model = self.send(border_reader_name) || self.send(border_writer_name)
              model.send attr, value
            end

            # reader for attribute of 'default' border
            define_method attr_reader_name do # e.g. table_border_color
              self.send(border_reader_name)&.send bdr_attr
            end
          end

          base.define_method "#{border_reader_name}_total_size" do # e.g. table_border_total_size
            self.send(border_reader_name)&.total_size
          end

          BorderModel::TYPES.each do |dir|
            model_writer_name = :"border_#{dir}" # e.g. border_top
            model_reader_name = :"#{base.attr_prefix}_border_#{dir}"
            # ATTRS << model_writer_name

            base.has_model_attribute model_writer_name,
                model: Caracal::Core::Models::BorderModel,
                default: nil

            # writer for optional border model, e.g. border_top
            base.define_method model_writer_name do |options = {}, &block|
              case options
              when Hash
                options.merge! type: dir
                instance_variable_set "@#{model_reader_name}", Caracal::Core::Models::BorderModel.new(options, &block)
              when Caracal::Core::Models::BorderModel
                options.instance_eval &block if block_given?
                instance_variable_set "@#{model_reader_name}", options
              else
                raise ArgumentError, "don't know how to handle #{options.inspect}, expecting hash or Caracal::Core::Models::BorderModel"
              end
            end

            BorderModel::ATTRS.each do |attr|
              bdr_attr         = :"border_#{attr}"               # e.g. border_color
              attr_writer_name = :"#{model_writer_name}_#{attr}" # e.g. border_top_color
              attr_reader_name = :"#{model_reader_name}_#{attr}" # e.g. table_border_top_color
              # ATTRS << attr_writer_name

              # writer for attribute of optional border, e.g. border_top_color
              base.define_method attr_writer_name do |v|
                model = self.send(model_reader_name) || self.send(model_writer_name)
                model&.send attr, v
              end

              # reader for attribute of optional border, e.g. table_border_top_color
              base.define_method attr_reader_name do
                model = self.send(model_reader_name) || self.send(border_reader_name)
                model&.send bdr_attr
              end
            end

            base.define_method "#{model_reader_name}_total_size" do # e.g. table_border_top_total_size
              model = self.send(model_reader_name) || self.send(border_reader_name)
              model&.total_size || 0
            end
          end
        end

      end
    end
  end
end
