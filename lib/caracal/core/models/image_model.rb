require 'caracal/core/models/base_model'


module Caracal
  module Core
    module Models

      # This class handles block options passed to the img method.
      #
      class ImageModel < BaseModel
        use_prefix :image

        RELATIVE_TOS = [:page, :margin, :column, :paragraph]
        WRAPS        = [:square, :top_and_bottom, :none, :behind]

        has_integer_attribute :ppi,    default: 72 # pixels per inch
        has_integer_attribute :width,  default: 0  # units in pixels. (will cause error)
        has_integer_attribute :height, default: 0  # units in pixels. (will cause error)
        has_integer_attribute :top,    default: 8  # units in pixels.
        has_integer_attribute :bottom, default: 8  # units in pixels.
        has_integer_attribute :left,   default: 8  # units in pixels.
        has_integer_attribute :right,  default: 8  # units in pixels.

        has_symbol_attribute :align, default: :left
        has_symbol_attribute :anchor

        # anchored images only
        has_integer_attribute :x                              # units in twips.
        has_integer_attribute :y                              # units in twips.
        has_symbol_attribute :relative_to, default: :page
        has_symbol_attribute :relative_to_x                   # defaults to relative_to
        has_symbol_attribute :relative_to_y                   # defaults to relative_to
        has_symbol_attribute :wrap, default: :top_and_bottom

        has_string_attribute :url
        has_string_attribute :data

        # initialization
        def initialize(options={}, &block)
          @image_ppi    = DEFAULT_IMAGE_PPI
          @image_width  = DEFAULT_IMAGE_WIDTH
          @image_height = DEFAULT_IMAGE_HEIGHT
          @image_align  = DEFAULT_IMAGE_ALIGN
          @image_top    = DEFAULT_IMAGE_TOP
          @image_bottom = DEFAULT_IMAGE_BOTTOM
          @image_left   = DEFAULT_IMAGE_LEFT
          @image_right  = DEFAULT_IMAGE_RIGHT
          @image_anchor = DEFAULT_IMAGE_ANCHOR
          @image_relative_to = DEFAULT_IMAGE_RELATIVE_TO
          @image_wrap   = DEFAULT_IMAGE_WRAP

          super(options, &block).tap do
            formatted_width
            formatted_height
          end
        end

        #=============== GETTERS ==============================

        [:width, :height].each do |m|
          define_method "formatted_#{m}" do
            value = send("image_#{m}")
            instance_variable_get "@cached_image_#{m}" or instance_variable_set "@cached_image_#{m}", pixels_to_emus(value, image_ppi)
          end
        end

        [:top, :bottom, :left, :right].each do |m|
          define_method "formatted_#{m}" do
            value = send("image_#{m}")
            pixels_to_emus(value, 72) # NOT image_ppi!
          end
        end

        [:x, :y].each do |m|
          define_method "formatted_#{m}" do
            value = send("image_#{m}")
            value * 635 unless value.nil? # twips to EMUs
          end
        end

        #=============== SETTERS ==============================

        def anchor(value)
          if value
            @image_anchor = value.to_s.to_sym
          else
            @image_anchor = nil
          end
        end

        #=============== VALIDATION ==============================

        def valid?
          [:ppi, :width, :height].all? { |a| validate_size a, at_least: 0 } and
            [:top, :bottom, :left, :right].all? { |a| validate("#{a} must not be negative") { send("image_#{a}").to_i >= 0 } } and
            [:relative_to, :relative_to_x, :relative_to_y].all? { |a| validate_inclusion a, within: RELATIVE_TOS } and
            validate_inclusion(:wrap, within: WRAPS, allow_nil: false)
        end

        private

        def option_keys
          [:url, :width, :height, :align, :top, :bottom, :left, :right, :data, :anchor, :x, :y, :relative_to, :relative_to_x, :relative_to_y, :wrap]
        end

        def pixels_to_emus(value, ppi)
          pixels        = value.to_i
          inches        = pixels / ppi.to_f
          emus_per_inch = 914400

          emus = (inches * emus_per_inch).to_i
        end

      end

    end
  end
end
