require 'spec_helper'
require 'tmpdir'

describe Caracal::Core::FileName do
  let(:file_name) { 'test.docx' }
  
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Configuration
  #-------------------------------------------------------------

  describe 'configuration tests' do
    
    # constants
    describe 'file name constants' do
      it { expect(subject.class::DEFAULT_FILE_NAME).to eq 'caracal.docx' }
    end
      
    # accessors
    describe 'file name readers' do
      it { expect(subject.name).to eq 'caracal.docx' }
      it { expect(subject.path).to eq './caracal.docx' }
    end
    
  end
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .file_name
    describe '.file_name' do
      let(:new_name)  { 'example.docx' }
      let(:actual)    { subject.name }
      
      before { subject.file_name(new_name) }
      
      describe 'when argument provided' do
        it { expect(actual).to eq new_name }
      end
      describe 'when argument nil' do
        let!(:previous) { subject.name }
        let(:new_name)  { nil }
        
        it { expect(actual).to eq previous }
      end
    end

    # .save
    describe '.save' do
      it 'writes ./caracal.docx by default' do
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) { subject.save }
          expect(File.file? File.join(dir, 'caracal.docx')).to be true
        end
      end
    end
    
  end
  
end