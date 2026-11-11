require 'spec_helper'

describe 'tab rendering' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:xml) do
    Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(Caracal::Document.new do |docx|
      docx.p do
        tabs [2880]
        text 'column at 0', end_tab: true
        text 'column at 2in'
      end
      docx.p tabs: [2880, 5760] do
        text 'column at 0', end_tab: true
        text 'column at 2in', end_tab: true
        text 'column at 4in'
      end
      docx.ul do
        li tabs: [1440] do
          text 'item', end_tab: true
          text 'at 1in'
        end
      end
    end))
  end

  let(:paragraphs) { xml.xpath('//w:body/w:p', ns) }

  def tab_positions(p)
    p.xpath('w:pPr/w:tabs/w:tab/@w:pos', ns).map(&:value)
  end

  it { expect(tab_positions paragraphs[0]).to eq %w(2880) }
  it { expect(tab_positions paragraphs[1]).to eq %w(2880 5760) }
  it { expect(tab_positions paragraphs[2]).to eq %w(1440) }
  it { expect(paragraphs[0].xpath('w:pPr/w:tabs/w:tab/@w:val', ns).map(&:value)).to eq %w(start) }
  it { expect(paragraphs[1].xpath('w:r', ns).map { |r| r.xpath('*', ns).map(&:name) }).to eq [%w(rPr t tab), %w(rPr t tab), %w(rPr t)] }
  it { expect(paragraphs[0].xpath('w:pPr/*', ns).map(&:name)).to eq %w(pStyle tabs contextualSpacing rPr) }
end
