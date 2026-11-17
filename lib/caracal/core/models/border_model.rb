require 'caracal/core/models/base_model'

module Caracal
  module Core
    module Models

      # This class handles block options passed to the page margins
      # method.
      class BorderModel < BaseModel
        ATTRS = [:color, :theme_color, :line, :size, :spacing].freeze
        TYPES = [:top, :bottom, :left, :right, :horizontal, :vertical].freeze

        # ST_Border: the line styles, then the art borders
        LINES = %i(nil none single thick double dotted dashed dotDash dotDotDash triple
            thinThickSmallGap thickThinSmallGap thinThickThinSmallGap thinThickMediumGap
            thickThinMediumGap thinThickThinMediumGap thinThickLargeGap thickThinLargeGap
            thinThickThinLargeGap wave doubleWave dashSmallGap dashDotStroked threeDEmboss
            threeDEngrave outset inset
            apples archedScallops babyPacifier babyRattle balloons3Colors balloonsHotAir
            basicBlackDashes basicBlackDots basicBlackSquares basicThinLines basicWhiteDashes
            basicWhiteDots basicWhiteSquares basicWideInline basicWideMidline basicWideOutline
            bats birds birdsFlight cabins cakeSlice candyCorn celticKnotwork certificateBanner
            chainLink champagneBottle checkedBarBlack checkedBarColor checkered christmasTree
            circlesLines circlesRectangles classicalWave clocks compass confetti confettiGrays
            confettiOutline confettiStreamers confettiWhite cornerTriangles couponCutoutDashes
            couponCutoutDots crazyMaze creaturesButterfly creaturesFish creaturesInsects
            creaturesLadyBug crossStitch cup decoArch decoArchColor decoBlocks diamondsGray
            doubleD doubleDiamonds earth1 earth2 earth3 eclipsingSquares1 eclipsingSquares2
            eggsBlack fans film firecrackers flowersBlockPrint flowersDaisies flowersModern1
            flowersModern2 flowersPansy flowersRedRose flowersRoses flowersTeacup flowersTiny
            gems gingerbreadMan gradient handmade1 handmade2 heartBalloon heartGray hearts
            heebieJeebies holly houseFunky hypnotic iceCreamCones lightBulb lightning1
            lightning2 mapPins mapleLeaf mapleMuffins marquee marqueeToothed moons mosaic
            musicNotes northwest ovals packages palmsBlack palmsColor paperClips papyrus
            partyFavor partyGlass pencils people peopleWaving peopleHats poinsettias
            postageStamp pumpkin1 pushPinNote2 pushPinNote1 pyramids pyramidsAbove quadrants
            rings safari sawtooth sawtoothGray scaredCat seattle shadowedSquares sharksTeeth
            shorebirdTracks skyrocket snowflakeFancy snowflakes sombrero southwest stars
            starsTop stars3d starsBlack starsShadowed sun swirligig tornPaper tornPaperBlack
            trees triangleParty triangles triangle1 triangle2 triangleCircle1 triangleCircle2
            shapes1 shapes2 twistedLines1 twistedLines2 vine waveline weavingAngles
            weavingBraid weavingRibbon weavingStrips whiteFlowers woodwork xIllusions
            zanyTriangles zigZag zigZagStitch custom).freeze

        use_prefix :border

        has_string_attribute :color, default: 'auto'

        has_model_attribute :theme_color,
            model: Caracal::Core::Models::ThemeColorModel

        has_symbol_attribute :line, default: :single
        has_symbol_attribute :type

        has_integer_attribute :size, default: 4 # 1/8 points
        has_integer_attribute :spacing          # points, rendered as 0 when nil

        # readers fall back to the (subclass) defaults, so that unset
        # attributes can be told apart from set ones (see #given?)
        ATTRS.each do |attr|
          define_method "border_#{attr}" do
            v = instance_variable_get "@border_#{attr}"
            v.nil? ? self.class.const_get("DEFAULT_BORDER_#{attr.upcase}") : v
          end
        end


        #-------------------------------------------------------------
        # Class Methods
        #-------------------------------------------------------------

        def self.formatted_type(type)
          {
            horizontal: 'insideH',
            vertical:   'insideV',
            top:        'top',
            bottom:     'bottom',
            left:       'left',
            right:      'right'
          }[type.to_s.to_sym]
        end

        #=============== GETTERS ==============================

        def given?(attr)
          not instance_variable_get("@border_#{attr}").nil?
        end

        def formatted_type
          self.class.formatted_type(border_type) || ''
        end

        def total_size
          if undefined?
            0
          else
            border_size + (2 * border_spacing.to_i)
          end
        end

        #=============== VALIDATION ==============================

        def valid?
          dims = [:size, :spacing]
          (undefined? or dims.all? {|d| validate_size d, at_least: 0, allow_nil: true }) and
              validate_inclusion :type, within: TYPES, allow_nil: true and
              validate_inclusion :line, within: LINES
        end

        def undefined?
          self.border_line == :none or self.border_line.nil?
        end

        private

        def option_keys
          ATTRS + [:type]
        end

      end
    end
  end
end
