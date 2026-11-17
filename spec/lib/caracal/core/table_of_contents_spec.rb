require 'spec_helper'

describe Caracal::Core::TableOfContents do
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .toc
    describe '.toc' do
      let!(:size) { subject.contents.size }
      
      before { subject.toc }
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::TableOfContentModel) }
    end
    
    # .table_of_contents
    describe '.toc' do
      let!(:size) { subject.contents.size }
      
      before { subject.table_of_contents }
      
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::TableOfContentModel) }
    end

    # invalid levels
    describe 'with invalid levels' do
      let(:message) { 'Table of contents start_level and end_level must be between 1 and 6, with end_level equal to or greater than start_level.' }

      it { expect { subject.toc start_level: 0 }.to raise_error(Caracal::Errors::InvalidModelError, message) }
      it { expect { subject.toc end_level: 7 }.to raise_error(Caracal::Errors::InvalidModelError, message) }
      it { expect { subject.toc start_level: 3, end_level: 2 }.to raise_error(Caracal::Errors::InvalidModelError, message) }
    end
  end
  
end