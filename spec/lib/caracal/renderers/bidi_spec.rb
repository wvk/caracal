require 'spec_helper'

describe 'right-to-left paragraphs' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style id: 'Arabic', name: 'Arabic', bidi: true, word_wrap: true
      docx.p 'نص', bidi: true, tabs: [720], line: 360
      docx.p 'text'
      docx.ol do
        li 'بند', bidi: true
      end
    end
  end

  let(:document)   { Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(docx)) }
  let(:styles)     { Nokogiri::XML(Caracal::Renderers::StylesRenderer.render(docx)) }
  let(:paragraphs) { document.xpath('//w:body/w:p', ns) }

  def ppr_names(p)
    p.xpath('w:pPr/*', ns).map(&:name)
  end

  it { expect(paragraphs[0].at_xpath('w:pPr/w:bidi/@w:val', ns).value).to eq 'true' }
  it { expect(ppr_names paragraphs[0]).to eq %w(pStyle tabs bidi spacing contextualSpacing rPr) }
  it { expect(paragraphs[1].at_xpath('w:pPr/w:bidi', ns)).to be_nil }

  it { expect(paragraphs[2].at_xpath('w:pPr/w:bidi/@w:val', ns).value).to eq 'true' }
  it { expect(ppr_names paragraphs[2]).to eq %w(pStyle numPr bidi ind contextualSpacing rPr) }

  it 'sets the direction of a paragraph style' do
    ppr = styles.at_xpath("//w:style[@w:styleId='Arabic']/w:pPr", ns)
    expect(ppr.xpath('*', ns).map(&:name)).to eq %w(wordWrap bidi spacing)
  end
end
