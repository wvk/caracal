require 'spec_helper'

describe 'rule rendering' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:document) do
    Caracal::Document.new do |docx|
      docx.hr
      docx.hr width: 2360, align: :left
      docx.hr width: 2360
      docx.hr width: 2360, align: :right, top: 0, bottom: 120, height: 60
      docx.hr width: 20000
      docx.table [[Caracal::Core::Models::TableCellModel.new(width: 4000) { hr width: 1000 }]]
    end
  end
  let(:xml)   { Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(document)) }
  let(:rules) { xml.xpath('//w:p[w:pPr/w:pBdr]', ns) }

  def indents(p)
    ind = p.at_xpath('w:pPr/w:ind', ns)
    ind && [ind['w:start'], ind['w:end']]
  end

  it { expect(rules.map {|p| indents p }).to eq [nil, %w(0 7000), %w(3500 3500), %w(7000 0), nil, %w(1500 1500)] }
  it { expect(rules[0].xpath('w:pPr/*', ns).map(&:name)).to eq %w(pBdr) }
  it { expect(rules[3].xpath('w:pPr/*', ns).map(&:name)).to eq %w(pBdr spacing ind) }
  it { expect(rules[3].at_xpath('w:pPr/w:spacing', ns).attributes.transform_values(&:value)).to eq('before' => '0', 'after' => '120', 'line' => '60', 'lineRule' => 'exact') }

  it 'rejects an unknown alignment' do
    expect { Caracal::Document.new {|docx| docx.hr align: :both } }.to raise_error Caracal::Errors::InvalidModelError
  end

  it 'rejects a negative spacing' do
    expect { Caracal::Document.new {|docx| docx.hr top: -1 } }.to raise_error Caracal::Errors::InvalidModelError
  end
end
