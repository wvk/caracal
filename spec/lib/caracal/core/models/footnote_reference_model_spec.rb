require 'spec_helper'

describe Caracal::Core::Models::FootnoteReferenceModel do
  let(:note) { Caracal::Core::Models::FootnoteModel.new content: 'Source' }

  subject { described_class.new footnote: note, size: 32, bold: true, vertical_align: :subscript, hide_mark: true }

  describe 'accessors' do
    it { expect(subject.footnote).to equal note }
    it { expect(subject.text_style).to eq 'FootnoteReference' }
    it { expect(subject.text_size).to eq 32 }
    it { expect(subject.text_bold).to eq true }
    it { expect(subject.text_vertical_align).to be_nil }
  end

  describe '.mark?' do
    it { expect(subject).not_to be_mark }
    it { expect(described_class.new).to be_mark }
  end

  describe '.apply_styles' do
    before { subject.apply_styles({ style: 'Other', vertical_align: :subscript, italic: true }, reverse: true) }

    it { expect(subject.text_style).to eq 'FootnoteReference' }
    it { expect(subject.text_vertical_align).to be_nil }
    it { expect(subject.text_italic).to eq true }
  end

  describe 'validation' do
    it { expect(subject).to be_valid }
    it { expect(described_class.new(highlight_color: 'pink')).not_to be_valid }
  end
end
