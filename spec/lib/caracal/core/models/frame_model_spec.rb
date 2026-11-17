require 'spec_helper'

describe Caracal::Core::Models::FrameModel do
  subject do
    described_class.new do
      width         2880
      height        1440
      x             7200
      y             720
      align         :right
      relative_to   :margin
      relative_to_x :page
      relative_to_y :paragraph
      wrap          :square

      p 'Frame text'
    end
  end



  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------

  describe 'configuration tests' do

    # constants
    describe 'constants' do
      it { expect(described_class::DEFAULT_FRAME_WIDTH).to eq nil }
      it { expect(described_class::DEFAULT_FRAME_HEIGHT).to eq nil }
      it { expect(described_class::DEFAULT_FRAME_ALIGN).to eq :left }
      it { expect(described_class::DEFAULT_FRAME_RELATIVE_TO).to eq :page }
      it { expect(described_class::DEFAULT_FRAME_WRAP).to eq :top_and_bottom }
    end

    # accessors
    describe 'accessors' do
      it { expect(subject.frame_width).to         eq 2880 }
      it { expect(subject.frame_height).to        eq 1440 }
      it { expect(subject.frame_x).to             eq 7200 }
      it { expect(subject.frame_y).to             eq 720 }
      it { expect(subject.frame_align).to         eq :right }
      it { expect(subject.frame_relative_to).to   eq :margin }
      it { expect(subject.frame_relative_to_x).to eq :page }
      it { expect(subject.frame_relative_to_y).to eq :paragraph }
      it { expect(subject.frame_wrap).to          eq :square }
    end

    describe 'defaults' do
      subject { described_class.new(width: 100, height: 100) { p 'Frame text' } }

      it { expect(subject.frame_x).to             eq nil }
      it { expect(subject.frame_y).to             eq nil }
      it { expect(subject.frame_align).to         eq :left }
      it { expect(subject.frame_relative_to).to   eq :page }
      it { expect(subject.frame_relative_to_x).to eq nil }
      it { expect(subject.frame_relative_to_y).to eq nil }
      it { expect(subject.frame_wrap).to          eq :top_and_bottom }
    end

  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    describe 'getters' do
      it { expect(subject.formatted_width).to  eq 1828800 } # twips to EMUs
      it { expect(subject.formatted_height).to eq 914400 }
      it { expect(subject.formatted_x).to      eq 4572000 }
      it { expect(subject.formatted_y).to      eq 457200 }
      it { expect(described_class.new(width: 100, height: 100) { p 'a' }.formatted_x).to eq nil }
    end

    describe 'contents' do
      subject do
        described_class.new width: 2880, height: 1440, document: Caracal::Document.new do
          h2 'Heading'
          p  'Paragraph'
          ul { li 'Item' }
          table [['A', 'B']]
        end
      end

      let(:classes) { subject.contents.map(&:class) }
      let(:table)   { subject.contents.grep(Caracal::Core::Models::TableModel).first }

      it { expect(classes).to eq [Caracal::Core::Models::ParagraphModel, Caracal::Core::Models::ParagraphModel, Caracal::Core::Models::ListModel, Caracal::Core::Models::TableModel, Caracal::Core::Models::ParagraphModel] }
      it { expect(subject.contents.first.paragraph_style).to eq 'Heading2' }
      it { expect(table.table_width).to eq 2880 }
      it { expect(table.grid_column_widths).to eq [1440, 1440] }

      # like a table cell, a frame ends in a paragraph
      it { expect(subject.contents.last.paragraph_line).to eq 20 }
    end

    describe 'block argument' do
      subject do
        text = 'from the surrounding scope'
        described_class.new(width: 100, height: 100) {|frame| frame.p text }
      end

      it { expect(subject.contents.first.runs.first.text_content).to eq 'from the surrounding scope' }
    end

  end


  #-------------------------------------------------------------
  # Validation
  #-------------------------------------------------------------

  describe 'validation' do
    def frame(**options)
      described_class.new({ width: 100, height: 100 }.merge(options)) { p 'Frame text' }
    end

    it { expect(subject.valid?).to eq true }
    it { expect(frame.valid?).to eq true }

    [:page, :margin, :column, :paragraph].each do |value|
      it { expect(frame(relative_to: value, relative_to_x: value, relative_to_y: value).valid?).to eq true }
    end

    [:square, :top_and_bottom, :none, :behind].each do |value|
      it { expect(frame(wrap: value).valid?).to eq true }
    end

    it { expect(frame(width: nil).valid?).to eq false }
    it { expect(frame(height: nil).valid?).to eq false }
    it { expect(frame(width: 0).valid?).to eq false }
    it { expect(frame(wrap: :tight).valid?).to eq false }
    it { expect(frame(wrap: nil).valid?).to eq false }
    it { expect(frame(relative_to: :line).valid?).to eq false }
    it { expect(frame(relative_to_x: :foo).valid?).to eq false }
    it { expect(frame(relative_to_y: :foo).valid?).to eq false }
    it { expect(frame(align: :justify).valid?).to eq false }
    it { expect(described_class.new(width: 100, height: 100).valid?).to eq false }
  end


  #-------------------------------------------------------------
  # Private Methods
  #-------------------------------------------------------------

  describe 'private method tests' do

    # .option_keys
    describe '.option_keys' do
      let(:actual)   { subject.send(:option_keys).sort }
      let(:expected) { [:width, :height, :x, :y, :align, :relative_to, :relative_to_x, :relative_to_y, :wrap].sort }

      it { expect(actual).to eq expected }
    end

  end

end
