require 'spec_helper'

describe 'character styles' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style do
        id   'MyCharStyle'
        name 'my char style'
        type 'character'
        bold true
      end
      docx.style id: 'Derived', name: 'derived', type: :character, base: 'MyCharStyle', italic: true
      docx.style id: 'Orphan',  name: 'orphan',  type: :character, base: 'Heading1'
      docx.p do
        text 'styled', style: 'MyCharStyle', color: 'ff0000'
        text 'plain'
        link 'link', 'https://example.com', style: 'Derived'
      end
    end
  end

  let(:styles)   { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx) }
  let(:document) { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(docx) }

  def style(id)
    styles.at_xpath("//w:style[@w:styleId='#{id}']", ns)
  end

  describe 'styles.xml' do
    it { expect(style('MyCharStyle')['w:type']).to eq 'character' }
    it { expect(style('MyCharStyle').xpath('*', ns).map(&:name)).to eq %w(name rPr) }
    it { expect(style('MyCharStyle').at_xpath('w:rPr/w:b/@w:val', ns).value).to eq 'true' }
    it { expect(style('Derived').at_xpath('w:basedOn/@w:val', ns).value).to eq 'MyCharStyle' }
    it { expect(style('Orphan').at_xpath('w:basedOn', ns)).to be_nil }
    it { expect(style('Hyperlink')['w:type']).to eq 'character' }
    it { expect(style('Hyperlink').at_xpath('w:pPr', ns)).to be_nil }
    it { expect(style('Heading1')['w:type']).to eq 'paragraph' }
  end

  describe 'document.xml' do
    let(:runs) { document.xpath('//w:body/w:p/w:r', ns) }

    it { expect(runs[0].xpath('w:rPr/*', ns).map(&:name)).to eq %w(rStyle color) }
    it { expect(runs[0].at_xpath('w:rPr/w:rStyle/@w:val', ns).value).to eq 'MyCharStyle' }
    it { expect(runs[1].at_xpath('w:rPr/w:rStyle', ns)).to be_nil }
    it { expect(document.at_xpath('//w:hyperlink/w:r/w:rPr/*[1]', ns).name).to eq 'rStyle' }
    it { expect(document.at_xpath('//w:hyperlink/w:r/w:rPr/w:rStyle/@w:val', ns).value).to eq 'Derived' }
    it { expect(document.at_xpath('//w:pPr/w:rPr/w:rStyle', ns)).to be_nil }
    it { expect(document.xpath('//w:hyperlink/w:r/w:rPr/*', ns).map(&:name)).to eq %w(rStyle) }
  end

  describe 'a styled link with explicit options' do
    let(:docx) do
      Caracal::Document.new {|docx| docx.p { link 'link', 'https://example.com', style: 'Hyperlink', color: 'ff0000', underline: false } }
    end
    let(:rpr) { document.at_xpath('//w:hyperlink/w:r/w:rPr', ns) }

    it { expect(rpr.xpath('*', ns).map(&:name)).to eq %w(rStyle color u) }
    it { expect(rpr.at_xpath('w:color/@w:val', ns).value).to eq 'ff0000' }
    it { expect(rpr.at_xpath('w:u/@w:val', ns).value).to eq 'none' }
  end
end
