require 'spec_helper'

describe 'style model classes' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:docx) do
    Caracal::Document.new do |docx|
      docx.style do
        id      'Marked'
        name    'marked'
        bgcolor 'ffff00'
        strike  true
      end
      docx.style do |s|
        s.id     'Struck'
        s.name   'struck'
        s.strike true
      end
      docx.style do
        id   'Grid'
        name 'grid'
        type :table
        conditional_format type: :firstRow, id: 'GridFirstRow', name: 'grid first row' do
          bold    true
          bgcolor 'cccccc'
        end
      end
      docx.style id: 'Plain', name: 'plain', bgcolor: 'eeeeee'
    end
  end

  let(:styles) { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx) }

  def style(id)
    styles.at_xpath("//w:style[@w:styleId='#{id}']", ns)
  end

  it { expect(docx.find_style('Title')).to be_an_instance_of Caracal::Core::Models::StyleModel }
  it { expect(docx.find_style('Subtitle')).to be_an_instance_of Caracal::Core::Models::StyleModel }
  it { expect(docx.find_style('Marked')).to be_an_instance_of Caracal::Core::Models::StyleModel }
  it { expect(docx.find_style('Grid')).to be_an_instance_of Caracal::Core::Models::TableStyleModel }

  it { expect(style('Marked').at_xpath('w:rPr/w:shd/@w:color', ns).value).to eq 'ffff00' }
  it { expect(style('Marked').at_xpath('w:rPr/w:strike/@w:val', ns).value).to eq 'true' }
  it { expect(style('Struck').at_xpath('w:rPr/w:strike/@w:val', ns).value).to eq 'true' }
  it { expect(style('Plain').at_xpath('w:rPr/w:shd/@w:color', ns).value).to eq 'eeeeee' }

  it { expect(style('Grid')['w:type']).to eq 'table' }
  it { expect(style('Grid').at_xpath("w:tblStylePr[@w:type='firstRow']/w:rPr/w:b/@w:val", ns).value).to eq 'true' }
  it { expect(style('Grid').at_xpath("w:tblStylePr[@w:type='firstRow']/w:tcPr/w:shd/@w:color", ns).value).to eq 'cccccc' }
end
