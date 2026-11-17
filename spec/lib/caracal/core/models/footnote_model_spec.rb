require 'spec_helper'

describe Caracal::Core::Models::FootnoteModel do
  subject do
    described_class.new content: 'Its source, ', size: 18 do
      link 'with a link', 'https://example.com/'
      text '.', italic: true
    end
  end

  let(:runs) { subject.runs }

  describe 'configuration tests' do
    describe 'accessors' do
      it { expect(subject.paragraph_style).to eq 'FootnoteText' }
      it { expect(subject.paragraph_size).to eq 18 }
      it { expect(described_class.new(content: 'x', style: 'MyNotes').paragraph_style).to eq 'MyNotes' }
    end
  end

  describe 'runs' do
    it 'opens with its mark and a space, then its text and the runs of its block' do
      expect(runs.map(&:class)).to eq [
        Caracal::Core::Models::FootnoteReferenceModel,
        Caracal::Core::Models::TextModel,
        Caracal::Core::Models::TextModel,
        Caracal::Core::Models::LinkModel,
        Caracal::Core::Models::TextModel
      ]
      expect(runs.drop(1).map(&:text_content)).to eq [' ', 'Its source, ', 'with a link', '.']
    end

    it { expect(runs.first).to be_mark }
    it { expect(runs.first.text_style).to eq 'FootnoteReference' }

    it 'formats its mark and the space like its text' do
      expect(runs.first(2).map(&:text_size)).to eq [18, 18]
    end

    it 'keeps its mark raised' do
      model = described_class.new content: 'x', vertical_align: :subscript
      expect(model.runs.first.text_vertical_align).to be_nil
    end

    it 'takes formatted runs and links in its block' do
      expect(runs.last.text_italic).to eq true
      expect(runs[3].link_href).to eq 'https://example.com/'
    end
  end

  describe 'validation' do
    it { expect(subject).to be_valid }
    it { expect(described_class.new).to be_valid }
  end

  describe '.footnote' do
    it { expect { subject.footnote 'nested' }.to raise_error(Caracal::Errors::InvalidModelError) }
  end
end
