require 'spec_helper'

describe 'next style' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style id: 'Lead', name: 'lead', next: 'Body'
      docx.style id: 'Body', name: 'body'
      docx.style do
        id        'Quote'
        name      'quote'
        self.next 'Body'
      end
      docx.style id: 'Grid',  name: 'grid',  type: :table,      next: 'Body'
      docx.style id: 'Cell',  name: 'cell',  type: :table_cell, next: 'Body'
      docx.style id: 'Mark',  name: 'mark',  type: :character,  next: 'Body'
    end
  end

  let(:styles) { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx) }

  def next_style(id)
    styles.at_xpath("//w:style[@w:styleId='#{id}']/w:next/@w:val", ns)&.value
  end

  it { expect(docx.find_style('Lead').style_next).to eq 'Body' }
  it { expect(next_style 'Lead').to eq 'Body' }
  it { expect(next_style 'Quote').to eq 'Body' }
  it { expect(next_style 'Body').to eq 'Normal' }
  it { expect(next_style 'Heading1').to eq 'Normal' }
  it { expect(%w(Grid Cell Mark TableNormal).map {|id| next_style id }).to all(be_nil) }
end
