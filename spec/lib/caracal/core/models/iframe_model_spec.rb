require 'spec_helper'

describe Caracal::Core::Models::IFrameModel do
  subject do
    described_class.new do
      url    'https://www.example.com/snippet.docx'
    end
  end



  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------

  describe 'configuration tests' do

    # accessors
    describe 'accessors' do
      it { expect(subject.iframe_url).to    eq 'https://www.example.com/snippet.docx' }
    end

  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    #=============== SETTERS ==========================

    # .url
    describe '.url' do
      before { subject.url('https://www.example.com/sample.docx') }

      it { expect(subject.iframe_url).to eq 'https://www.example.com/sample.docx' }
    end

    # .data
    describe '.data' do
      before { subject.data('DOCX data follows here') }

      it { expect(subject.iframe_data).to eq 'DOCX data follows here' }
    end


    #=============== VALIDATION ===========================

    describe '.valid?' do
      describe 'when either value present' do
        it { expect(subject.valid?).to eq true }
      end
      describe 'when neither value present' do
        before do
          subject.url(nil)
          subject.data(nil)
        end
        it { expect(subject.valid?).to eq false }
      end
    end

    #=============== PROCESSING =======================

    describe '.preprocess!' do
      let(:fixture)  { File.expand_path '../../../../support/_fixtures/snippet.docx', __dir__ }
      let(:document) { Caracal::Document.new }
      let(:model)    { described_class.new url: source, document: document }

      describe 'when url is a local path' do
        let(:source) { fixture }

        before { model.preprocess! }

        it { expect(model.namespaces).not_to be_empty }
      end
      describe 'when url is a web address' do
        let(:source) { 'https://www.example.com/snippet.docx' }

        before do
          allow(URI).to receive(:open).with(source, 'rb').and_yield(StringIO.new(File.binread fixture))
          model.preprocess!
        end

        it { expect(model.namespaces).not_to be_empty }
      end
    end

  end


  #-------------------------------------------------------------
  # Private Methods
  #-------------------------------------------------------------

  describe 'private method tests' do

    # .option_keys
    describe '.option_keys' do
      let(:actual)   { subject.send(:option_keys).sort }
      let(:expected) { [:url, :data].sort }

      it { expect(actual).to eq expected }
    end

  end

end
