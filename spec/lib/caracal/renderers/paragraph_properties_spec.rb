require 'spec_helper'

describe 'paragraph keep options and indents' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style id: 'Quote', name: 'quote', left: 720, right: 360
      docx.style id: 'Both', name: 'both', left: 720, indent_left: 1440
      docx.p 'kept', keep_next: true, keep_lines: true, widow_control: false, left: 720, right: 360
      docx.p 'indent form' do
        indent left: 360, right: 180
      end
      docx.p 'plain'
      docx.ul do
        li 'item', keep_lines: true, left: 360, right: 180 do
          ul { li 'nested' }
          text 'more'
        end
      end
    end
  end

  let(:document)   { Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(docx)) }
  let(:styles)     { Nokogiri::XML(Caracal::Renderers::StylesRenderer.render(docx)) }
  let(:paragraphs) { document.xpath('//w:body/w:p', ns) }

  def ppr_names(p)
    p.xpath('w:pPr/*', ns).map(&:name)
  end

  def ind(node)
    node.at_xpath('w:pPr/w:ind', ns)&.attributes&.transform_values(&:value)
  end

  it { expect(ppr_names paragraphs[0]).to eq %w(pStyle keepNext keepLines widowControl ind contextualSpacing rPr) }
  it { expect(paragraphs[0].at_xpath('w:pPr/w:keepLines/@w:val', ns).value).to eq 'true' }
  it { expect(paragraphs[0].at_xpath('w:pPr/w:widowControl/@w:val', ns).value).to eq 'false' }
  it { expect(ind paragraphs[0]).to eq('start' => '720', 'end' => '360') }
  it { expect(ind paragraphs[1]).to eq('start' => '360', 'end' => '180') }
  it { expect(ppr_names paragraphs[2]).to eq %w(pStyle contextualSpacing rPr) }

  it 'moves a list item, number included, and indents its end' do
    expect(ppr_names paragraphs[3]).to eq %w(pStyle keepLines numPr ind contextualSpacing rPr)
    expect(ind paragraphs[3]).to eq('start' => '1080', 'end' => '180', 'hanging' => '359')
  end

  it { expect(ind paragraphs[4]).to eq('start' => '1440', 'hanging' => '359') }
  it { expect(ind paragraphs[5]).to eq('start' => '1080', 'end' => '180') }

  it 'indents paragraph styles' do
    expect(ind styles.at_xpath("//w:style[@w:styleId='Quote']", ns)).to eq('start' => '720', 'end' => '360')
    expect(ind styles.at_xpath("//w:style[@w:styleId='Both']", ns)).to eq('start' => '1440')
  end

  it 'rejects an indent without a side' do
    expect { Caracal::Document.new {|d| d.p('x') { indent 720 } } }.to raise_error Caracal::Errors::InvalidModelError
  end
end
