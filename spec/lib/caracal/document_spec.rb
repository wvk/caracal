require 'spec_helper'

describe Caracal::Document do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  def texts(document)
    Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(document)).xpath('//w:t', ns).map(&:text)
  end

  describe 'block' do
    it 'accepts a lambda' do
      expect(texts described_class.new(&-> { p 'lambda' })).to eq ['lambda']
    end

    it 'passes the document to a block with an argument' do
      expect(texts described_class.new {|docx| docx.p 'argument' }).to eq ['argument']
    end
  end
end
