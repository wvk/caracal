require 'spec_helper'

describe 'line spacing' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style id: 'Exact', name: 'exact', line: 300, line_rule: :exact
      docx.style id: 'Auto',  name: 'auto',  line: 360, line_rule: 'auto'
      docx.p 'default', line: 400
      docx.p 'exact',   line: 400, line_rule: :exact
      docx.p 'auto',    line: 480, line_rule: :auto
      docx.p 'none'
      docx.ul { li 'item', line: 300 }
    end
  end

  let(:styles)   { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx) }
  let(:document) { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(docx) }

  def style_spacing(id)
    styles.at_xpath("//w:style[@w:styleId='#{id}']/w:pPr/w:spacing", ns)
  end

  def paragraph_spacing(text)
    document.at_xpath("//w:p[w:r/w:t='#{text}']/w:pPr/w:spacing", ns)
  end

  describe 'styles.xml' do
    it { expect(style_spacing('Title')['w:lineRule']).to eq 'atLeast' }
    it { expect(style_spacing('Heading1')['w:lineRule']).to eq 'atLeast' }
    it { expect(style_spacing('Heading1')['w:line']).to eq '360' }
    it { expect(style_spacing('Exact')['w:lineRule']).to eq 'exact' }
    it { expect(style_spacing('Auto')['w:lineRule']).to eq 'auto' }
    it { expect(styles.at_xpath('//w:pPrDefault//w:spacing/@w:lineRule', ns).value).to eq 'atLeast' }
    it { expect(styles.at_xpath('//w:pPrDefault//w:spacing/@w:line', ns).value).to eq '320' }
  end

  describe 'document.xml' do
    it { expect(paragraph_spacing('default')['w:lineRule']).to eq 'atLeast' }
    it { expect(paragraph_spacing('exact')['w:lineRule']).to eq 'exact' }
    it { expect(paragraph_spacing('auto')['w:lineRule']).to eq 'auto' }
    it { expect(paragraph_spacing('auto')['w:line']).to eq '480' }
    it { expect(paragraph_spacing('none')).to be_nil }
    it { expect(paragraph_spacing('item')['w:lineRule']).to eq 'atLeast' }
  end

  describe 'validation' do
    let(:doc) { Caracal::Document.new }

    it { expect { doc.style id: 'X', name: 'x', line_rule: :bogus }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { doc.p 'x', line: 300, line_rule: :bogus }.to raise_error Caracal::Errors::InvalidModelError }
  end
end
