require 'spec_helper'

describe 'table of contents rendering' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  def document_xml(&block)
    Nokogiri::XML Caracal::Renderers::DocumentRenderer.new(Caracal::Document.new(&block)).to_xml
  end

  # texts shown in place of the PAGEREF results
  def placeholders(xml)
    xml.xpath("//w:hyperlink/w:r[w:instrText[contains(., 'PAGEREF')]]/following-sibling::w:r[2]/w:t", ns).map(&:text)
  end

  describe 'page number placeholder' do
    it 'defaults to #' do
      xml = document_xml {|docx| docx.toc; docx.h1 'Introduction' }
      expect(placeholders(xml)).to eq ['#']
    end

    it 'accepts the placeholder option' do
      xml = document_xml {|docx| docx.toc placeholder: '...'; docx.h1 'Introduction' }
      expect(placeholders(xml)).to eq ['...']
    end

    it 'accepts the placeholder in block form' do
      xml = document_xml {|docx| docx.toc { placeholder '0' }; docx.h1 'Introduction' }
      expect(placeholders(xml)).to eq ['0']
    end
  end
end
