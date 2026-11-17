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

  describe 'heading' do
    def headings(xml)
      xml.xpath("//w:p[w:pPr/w:pStyle/@w:val='TOCHeading']", ns)
    end

    it 'shows the legend' do
      xml = document_xml {|docx| docx.toc legend: 'Contents'; docx.h1 'Introduction' }
      expect(headings(xml).map(&:text)).to eq ['Contents']
    end

    it 'is omitted without a legend' do
      xml = document_xml {|docx| docx.toc; docx.h1 'Introduction' }
      expect(headings(xml)).to be_empty
    end

    it 'is omitted with an empty legend' do
      xml = document_xml {|docx| docx.toc legend: ''; docx.h1 'Introduction' }
      expect(headings(xml)).to be_empty
    end

    it 'leaves the TOC field first in the body without a legend' do
      xml = document_xml {|docx| docx.toc; docx.h1 'Introduction' }
      first = xml.at_xpath('//w:body/w:p[1]', ns)
      expect(first.at_xpath('w:r[1]/w:fldChar/@w:fldCharType', ns)&.value).to eq 'begin'
      expect(first.at_xpath('w:r/w:instrText', ns)&.text).to include 'TOC'
    end
  end

  describe 'page breaks' do
    it 'adds none before the TOC' do
      xml = document_xml {|docx| docx.toc legend: 'Contents'; docx.h1 'Introduction' }
      expect(xml.xpath("//w:br[@w:type='page']", ns)).to be_empty
    end

    it 'keeps a page break added by the caller' do
      xml = document_xml {|docx| docx.page; docx.toc; docx.h1 'Introduction' }
      expect(xml.xpath("//w:br[@w:type='page']", ns).size).to eq 1
    end
  end

  describe 'field structure' do
    # field char types in document order, each begin with its instruction
    def field_chars(xml)
      xml.xpath('//w:fldChar | //w:instrText', ns).map {|node| node.name == 'instrText' ? node.text.split.first : node['w:fldCharType'] }
    end

    it 'nests the PAGEREF fields in the TOC field' do
      xml = document_xml {|docx| docx.toc; docx.h1 'Introduction' }
      expect(field_chars(xml)).to eq %w(begin TOC separate begin PAGEREF separate end end)
    end

    it 'is balanced without matching headings' do
      xml = document_xml {|docx| docx.toc start_level: 2, end_level: 3; docx.h1 'Introduction' }
      expect(field_chars(xml)).to eq %w(begin TOC separate end)
    end

    it 'is balanced without any headings' do
      xml = document_xml {|docx| docx.toc }
      expect(field_chars(xml)).to eq %w(begin TOC separate end)
    end
  end

  describe 'settings' do
    def settings_xml(&block)
      Nokogiri::XML Caracal::Renderers::SettingsRenderer.new(Caracal::Document.new(&block)).to_xml
    end

    it 'asks Word to update fields on open when there is a TOC' do
      xml = settings_xml {|docx| docx.toc; docx.h1 'Introduction' }
      expect(xml.at_xpath('//w:updateFields/@w:val', ns)&.value).to eq 'true'
    end

    it 'places updateFields before compat, as CT_Settings requires' do
      xml = settings_xml {|docx| docx.toc }
      names = xml.root.element_children.map(&:name)
      expect(names.index('updateFields')).to eq names.index('compat') - 1
    end

    it 'omits updateFields without a TOC' do
      xml = settings_xml {|docx| docx.h1 'Introduction' }
      expect(xml.at_xpath('//w:updateFields', ns)).to be_nil
    end
  end
end
