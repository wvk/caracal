require 'spec_helper'

describe Caracal::Core::Models::TableCellModel do
  subject do
    described_class.new do
      bgcolor      'cccccc'
      # margins do
        top           101
        bottom        102
        left          103
        right         104
      # end
      width           2000
      content_vertical_align :bottom
    end
  end

  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------

  describe 'configuration tests' do

    # constants
    describe 'constants' do
      it { expect(described_class::DEFAULT_CELL_BGCOLOR).to        eq nil }
      it { expect(described_class::DEFAULT_CELL_VERTICAL_ALIGN).to eq nil }
      it { expect(described_class::DEFAULT_CELL_CONTENT_VERTICAL_ALIGN).to eq nil }
      # it { expect(described_class::DEFAULT_CELL_MARGINS).to               be_a(Caracal::Core::Models::MarginModel) }
      it { expect(described_class::DEFAULT_CELL_TOP).to            eq nil }
      it { expect(described_class::DEFAULT_CELL_BOTTOM).to         eq nil }
      it { expect(described_class::DEFAULT_CELL_LEFT).to           eq nil }
      it { expect(described_class::DEFAULT_CELL_RIGHT).to          eq nil }
    end

    # accessors
    describe 'accessors' do
      it { expect(subject.cell_bgcolor).to        eq 'cccccc' }
      it { expect(subject.cell_top).to            eq 101 }
      it { expect(subject.cell_bottom).to         eq 102 }
      it { expect(subject.cell_left).to           eq 103 }
      it { expect(subject.cell_right).to          eq 104 }
      it { expect(subject.cell_width).to          eq 2000 }
      it { expect(subject.cell_content_vertical_align).to eq :bottom }
    end

  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    #=============== DATA ACCESSORS ====================

    describe 'data tests' do

      # .contents
      describe '.contents' do
        it { expect(subject.contents).to be_a(Array) }
      end

    end


    #=============== GETTERS ==========================

    describe 'getter tests' do

      # margin attrs
      describe 'margin attr tests' do
        before do
          subject.top 201
          subject.bottom 202
          subject.left 203
          subject.right 204
        end

        it { expect(subject.cell_top).to eq 201 }
        it { expect(subject.cell_bottom).to eq 202 }
        it { expect(subject.cell_left).to eq 203 }
        it { expect(subject.cell_right).to eq 204 }
      end

    end


    #=============== SETTERS ==========================

    # .margins
    describe '.margins' do
      def margins_of(cell)
        [cell.cell_top, cell.cell_bottom, cell.cell_left, cell.cell_right]
      end

      describe 'with a hash' do
        before { subject.margins top: 0, left: 50 }

        it { expect(margins_of(subject)).to eq [0, 102, 50, 104] }
      end

      describe 'with a block' do
        before { subject.margins { bottom 7; right 8 } }

        it { expect(margins_of(subject)).to eq [101, 7, 103, 8] }
      end

      describe 'as option' do
        let(:cell) { described_class.new margins: { top: 0, bottom: 100, left: 0, right: 200 } }

        it { expect(margins_of(cell)).to eq [0, 100, 0, 200] }
      end

      describe 'within the cell block' do
        let(:cell) do
          described_class.new do
            margins do
              top    10
              bottom 20
            end
            p 'text'
          end
        end

        it { expect(margins_of(cell)).to eq [10, 20, nil, nil] }
      end

      describe 'via apply_styles' do
        before { subject.apply_styles({ margins: { left: 0 } }) }

        it { expect(margins_of(subject)).to eq [101, 102, 0, 104] }
      end

      describe 'with an unknown side' do
        it { expect { subject.margins middle: 1 }.to raise_error(RuntimeError) }
      end
    end


    #=============== SETTERS ==========================

    # .bgcolor
    describe '.bgcolor' do
      before { subject.bgcolor('999999') }

      it { expect(subject.cell_bgcolor).to eq '999999' }
    end

    # .width
    describe '.width' do
      before { subject.width(7500) }

      it { expect(subject.cell_width).to eq 7500 }
    end

    #.vertical_allign
    describe '.vertical_align' do
      before { subject.vertical_align(:center) }

      it { expect(subject.cell_vertical_align).to eq :center }
    end

    describe '.border_top' do
      before { subject.border_top line: :double, color: 'ffffff', size: 8 }

      it { expect(subject.cell_border_top_line).to eq :double }
      it { expect(subject.cell_border_top_color).to eq 'ffffff' }
      it { expect(subject.cell_border_top_size).to eq 8 }

      it { expect(subject.cell_border_top).to be_a Caracal::Core::Models::BorderModel }
      it { expect(subject.cell_border_top.border_line).to eq :double }
      it { expect(subject.cell_border_top.border_color).to eq 'ffffff' }
      it { expect(subject.cell_border_top.border_size).to eq 8 }
    end

    describe '.border_top_line' do
      before { subject.border_top_line :double }

      it { expect(subject.cell_border_top_line).to eq :double }
      it { expect(subject.cell_border_top.border_line).to eq :double }
    end

    describe '.border_top_size' do
      before { subject.border_top_size 8 }

      it { expect(subject.cell_border_top_size).to eq 8 }
      it { expect(subject.cell_border_top.border_size).to eq 8 }
    end

    describe '.border_top theme_color with hash args' do
      before { subject.border_top theme_color: {ref: :dark2, color: '333333'} }

      it { expect(subject.cell_border_top_theme_color).to be_a Caracal::Core::Models::ThemeColorModel }
      it { expect(subject.cell_border_top_theme_color.theme_color_ref).to eq :dark2 }
      it { expect(subject.cell_border_top_theme_color.theme_color_val).to eq '333333' }
    end

    describe '.border_top theme_color with symbol arg' do
      before { subject.border_top theme_color: :dark2 }

      it { expect(subject.cell_border_top_theme_color).to be_a Caracal::Core::Models::ThemeColorModel }
      it { expect(subject.cell_border_top_theme_color.theme_color_ref).to eq :dark2 }
      it { expect(subject.cell_border_top_theme_color.theme_color_val).to eq 'auto' }
    end

    describe '.border_top_theme_color with symbol arg' do
      before { subject.border_top_theme_color :dark2 }

      it { expect(subject.cell_border_top_theme_color).to be_a Caracal::Core::Models::ThemeColorModel }
      it { expect(subject.cell_border_top_theme_color.theme_color_ref).to eq :dark2 }
      it { expect(subject.cell_border_top_theme_color.theme_color_val).to eq 'auto' }
    end

    describe '.border_top theme_color with block' do
      before do
        subject.border_top do
          theme_color do
            ref :dark2
            color '333333'
          end
        end
      end

      it { expect(subject.cell_border_top_theme_color).to be_a Caracal::Core::Models::ThemeColorModel }
      it { expect(subject.cell_border_top_theme_color.theme_color_ref).to eq :dark2 }
      it { expect(subject.cell_border_top_theme_color.theme_color_val).to eq '333333' }
    end


    #=============== CONTENT FNS =======================

    describe 'content functions' do

      # .p
      describe '.p' do
        let!(:size) { subject.contents.size }

        before { subject.p }

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ParagraphModel) }
      end

      # .img
      describe '.img' do
        let!(:size) { subject.contents.size }

        before { subject.img 'https://www.google.com/images/srpr/logo11w.png', width: 538, height: 190 }

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ImageModel) }
      end

      # .ol
      describe '.ol' do
        let!(:size) { subject.contents.size }

        before do
          subject.ol do
            li 'Item 1'
          end
        end

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ListModel) }
      end

      # .ul
      describe '.ul' do
        let!(:size) { subject.contents.size }

        before do
          subject.ul do
            li 'Item 1'
          end
        end

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ListModel) }
      end

      # .hr
      describe '.hr' do
        let!(:size) { subject.contents.size }

        before { subject.hr }

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::RuleModel) }
      end

      # .table
      describe '.table' do
        let!(:size) { subject.contents.size }

        before { subject.table [['Sample Text']] }

        it { expect(subject.contents.size).to eq size + 1 }
        it { expect(subject.contents.last).to be_a(Caracal::Core::Models::TableModel) }
      end

      # text
      [:p, :h1, :h2, :h3, :h4, :h5, :h6].each do |cmd|
        describe ".#{ cmd }" do
          let!(:size) { subject.contents.size }

          before { subject.send(cmd, 'Sample text.') }

          it { expect(subject.contents.size).to eq size + 1 }
          it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ParagraphModel) }
        end
      end

    end


    #=============== VALIDATION ========================

    describe '.valid?' do
      describe 'when content provided' do
        before { allow(subject).to receive(:contents).and_return(['a']) }

        it { expect(subject.valid?).to eq true }
      end
      describe 'when content not provided' do
        before { allow(subject).to receive(:contents).and_return([]) }

        it { expect(subject.valid?).to eq false }
      end
    end

  end


  #-------------------------------------------------------------
  # Private Methods
  #-------------------------------------------------------------

  describe 'private method tests' do

    # .option_keys
    describe '.option_keys' do
      let(:actual)     { subject.send(:option_keys).sort }
      let(:expected)   { [:bgcolor, :bgstyle, :border, :border_color, :border_line, :border_size, :border_spacing, :border_theme_color, :bottom, :colspan, :left, :margins, :right, :rowspan, :style, :theme_bgcolor, :top, :vertical_align, :content_vertical_align, :width, :border_bottom, :border_horizontal, :border_vertical, :border_top, :border_left, :border_right, :font, :caps, :small_caps, :highlight_color, :italic, :align, :bold, :rtl, :size, :strike, :underline, :whitespace, :color, :theme_color].sort }

      it { expect(actual).to eq expected }
    end

  end

end
