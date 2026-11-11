require 'spec_helper'

describe Caracal::Core::HeadingNumbering do
  subject { Caracal::Document.new }

  describe '.heading_numbering' do
    it { expect(subject.heading_numbering?).to be false }

    context 'with a block' do
      let!(:model) do
        subject.heading_numbering do
          h1 text: '%1.'
          h2 fmt: :upperRoman, text: '%1.%2', suff: :tab
        end
      end

      it { expect(subject.heading_numbering?).to be true }
      it { expect(model.id).to eq 1 }
      it { expect(model.heading_numbering_name).to eq 'Caracal heading numbering' }
      it { expect(model.to_h[:h1]).to eq(style_id: 'Heading1', ilvl: 0, fmt: 'decimal', lvl_text: '%1.', suff: 'space') }
      it { expect(model.to_h[:h2]).to eq(style_id: 'Heading2', ilvl: 1, fmt: 'upperRoman', lvl_text: '%1.%2', suff: 'tab') }
      it { expect(model.to_h[:h3]).to eq(style_id: 'Heading3', ilvl: 2, fmt: 'none', lvl_text: '', suff: 'nothing') }
      it { expect(model.ilvl_for('Heading6')).to eq 5 }
      it { expect(model.ilvl_for('Normal')).to be_nil }
    end

    context 'with an options hash' do
      let!(:model) { subject.heading_numbering h1: { text: '%1.' }, h2: { fmt: 'lowerLetter', text: '%1.%2)' } }

      it { expect(model.to_h[:h1]).to include(fmt: 'decimal', lvl_text: '%1.', suff: 'space') }
      it { expect(model.to_h[:h2]).to include(fmt: 'lowerLetter', lvl_text: '%1.%2)') }
    end

    context 'with an unknown level' do
      it { expect { subject.heading_numbering h7: { text: '%7' } }.to raise_error(Caracal::Errors::InvalidModelError) }
    end

    context 'with an unknown format' do
      it { expect { subject.heading_numbering { h1 fmt: 'klingon' } }.to raise_error(Caracal::Errors::InvalidModelError) }
    end

    context 'with an unknown suffix' do
      it { expect { subject.heading_numbering { h1 suff: 'dash' } }.to raise_error(Caracal::Errors::InvalidModelError) }
    end
  end
end
