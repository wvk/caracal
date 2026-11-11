require 'open-uri'
require 'caracal/core/models/base_model'
require 'caracal/image_size'


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
        has_integer_attribute :width               # units in pixels. defaults to the image's own size.
        has_integer_attribute :height              # units in pixels. defaults to the image's own size.
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
            complete_size
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
          validate(@size_error.to_s) { @size_error.nil? } and
            [:ppi, :width, :height].all? { |a| validate_size a, at_least: 0 } and
            [:top, :bottom, :left, :right].all? { |a| validate("#{a} must not be negative") { send("image_#{a}").to_i >= 0 } } and
            [:relative_to, :relative_to_x, :relative_to_y].all? { |a| validate_inclusion a, within: RELATIVE_TOS } and
            validate_inclusion(:wrap, within: WRAPS, allow_nil: false)
        end

        private

        # Fills in a missing width and/or height from the image data, keeping
        # the aspect ratio. Data read from the url is kept for the media part.
        def complete_size
          return if image_width and image_height

          if image_data.to_s.empty? and image_url
            begin
              @image_data = read_url
            rescue StandardError => e
              return @size_error = "could not read #{image_url} to determine its size (#{e.message}); pass width and height"
            end
          end

          w, h = Caracal::ImageSize.read image_data
          if w.nil?
            @size_error = "could not determine the size of #{image_url || 'the image data'} (PNG, JPEG and GIF are supported); pass width and height"
          elsif image_width
            @image_height = (image_width * h / w.to_f).round
          elsif image_height
            @image_width = (image_height * w / h.to_f).round
          else
            @image_width, @image_height = w, h
          end
        end

        # NOTICE: this potentially opens a web resource!
        def read_url
          if image_url.match? %r{\A[a-z][a-z0-9+.-]*://}i
            URI.open(image_url, 'rb') { |io| io.read }
          else
            File.binread image_url
          end
        end

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
