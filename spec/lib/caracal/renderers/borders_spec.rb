require 'spec_helper'

describe 'border rendering' do
  let(:ns)   { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:data) { [['A', 'B'], ['C', 'D']] }

  def document_xml(&block)
    Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(Caracal::Document.new(&block))
  end

  def attrs(node)
    node.attributes.transform_values(&:value)
  end

  def table_borders(xml)
    xml.xpath('//w:tblPr/w:tblBorders/*', ns).to_h { |n| [n.name, attrs(n)] }
  end

  describe 'hr' do
    it 'renders a single 1/2 pt rule by default' do
      xml = document_xml { |docx| docx.hr }
      expect(attrs xml.at_xpath('//w:pBdr/w:top', ns)).to eq('val' => 'single', 'sz' => '4', 'space' => '1', 'color' => 'auto')
    end

    it 'renders given options' do
      xml = document_xml { |docx| docx.hr { color '333333'; line :double; size 8; spacing 4 } }
      expect(attrs xml.at_xpath('//w:pBdr/w:top', ns)).to eq('val' => 'double', 'sz' => '8', 'space' => '4', 'color' => '333333')
    end
  end

  describe 'table without border options' do
    it { expect(document_xml { |docx| docx.table data }.at_xpath('//w:tblBorders', ns)).to be_nil }
  end

  describe 'table with border_size' do
    let(:borders) { table_borders document_xml { |docx| docx.table data, border_size: 4 } }

    it { expect(borders.keys).to eq %w(top left bottom right insideH insideV) }
    it { expect(borders.values.uniq).to eq [{ 'val' => 'single', 'sz' => '4', 'space' => '0', 'color' => 'auto' }] }
  end

  { border_color: 'ff0000', border_spacing: 2 }.each do |option, value|
    describe "table with #{option} only" do
      let(:borders) { table_borders document_xml { |docx| docx.table data, option => value } }

      it { expect(borders.size).to eq 6 }
      it { expect(borders.values.map { |b| b['val'] }.uniq).to eq %w(single) }
      it { expect(borders.values.flat_map(&:values)).to all(satisfy { |v| not v.empty? }) }
    end
  end

  describe 'table with a per-edge border only' do
    let(:borders) { table_borders document_xml { |docx| docx.table(data) { border_bottom size: 12 } } }

    it { expect(borders).to eq('bottom' => { 'val' => 'single', 'sz' => '12', 'space' => '0', 'color' => 'auto' }) }
  end

  describe 'table with border options and a per-edge line' do
    let(:borders) do
      table_borders(document_xml do |docx|
        docx.table data, border_size: 8, border_color: '0000ff' do
          border_top line: :double
        end
      end)
    end

    it { expect(borders.keys).to eq %w(top left bottom right insideH insideV) }
    it { expect(borders['top']).to eq('val' => 'double', 'sz' => '8', 'space' => '0', 'color' => '0000ff') }
    it { expect(borders['left']).to eq('val' => 'single', 'sz' => '8', 'space' => '0', 'color' => '0000ff') }
  end

  describe 'table with border_spacing' do
    let(:xml) { document_xml { |docx| docx.table data, border_size: 4, border_spacing: 3 } }

    it { expect(xml.at_xpath('//w:tblPr/w:tblCellSpacing/@w:w', ns).value).to eq '3' }
    it { expect(table_borders(xml).values.map { |b| b['space'] }.uniq).to eq %w(3) }
  end
end
