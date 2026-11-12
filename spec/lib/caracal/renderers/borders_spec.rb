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

  describe 'table with border_color only' do
    let(:borders) { table_borders document_xml { |docx| docx.table data, border_color: 'ff0000' } }

    it 'defaults to a 1/2 pt border' do
      expect(borders.values.uniq).to eq [{ 'val' => 'single', 'sz' => '4', 'space' => '0', 'color' => 'ff0000' }]
    end
  end

  describe 'table with a per-edge line only' do
    let(:borders) { table_borders document_xml { |docx| docx.table(data) { border_bottom line: :double } } }

    it { expect(borders).to eq('bottom' => { 'val' => 'double', 'sz' => '4', 'space' => '0', 'color' => 'auto' }) }
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

  describe 'paragraph borders' do
    def p_borders(**options, &block)
      xml = document_xml { |docx| docx.p 'x', **options, &block }
      xml.xpath('//w:p/w:pPr/w:pBdr/*', ns).to_h { |n| [n.name, attrs(n)] }
    end

    it 'draws a box from border_color' do
      expect(p_borders border_color: 'ff0000').to eq %w(top left bottom right).to_h { |e| [e, { 'val' => 'single', 'sz' => '4', 'space' => '0', 'color' => 'ff0000' }] }
    end

    it 'renders border_theme_color with its hex fallback' do
      expect(p_borders(border_theme_color: :accent1)['top']).to eq('val' => 'single', 'sz' => '4', 'space' => '0', 'themeColor' => 'accent1', 'color' => '00539B')
    end

    it 'renders border_line, border_size and border_spacing' do
      expect(p_borders(border_line: :double, border_size: 8, border_spacing: 4)['left']).to eq('val' => 'double', 'sz' => '8', 'space' => '4', 'color' => 'auto')
    end

    it 'renders a border hash' do
      expect(p_borders(border: { color: '0000ff' }).keys).to eq %w(top left bottom right)
    end

    it 'renders per-edge borders' do
      expect(p_borders(border_bottom: { size: 12 })).to eq('bottom' => { 'val' => 'single', 'sz' => '12', 'space' => '0', 'color' => 'auto' })
    end

    it 'renders per-edge shorthands in a block' do
      expect(p_borders { border_top_color 'ff0000' }).to eq('top' => { 'val' => 'single', 'sz' => '4', 'space' => '0', 'color' => 'ff0000' })
    end

    it 'renders an explicit horizontal border as between' do
      expect(p_borders(border_color: 'ff0000', border_horizontal: { line: :dashed }).keys).to eq %w(top left bottom right between)
    end
  end

  describe 'paragraph style borders' do
    let(:xml) do
      Nokogiri::XML Caracal::Renderers::StylesRenderer.render(Caracal::Document.new { |docx| docx.style id: 'Boxed', name: 'Boxed', border_color: '00ff00' })
    end

    it { expect(xml.xpath("//w:style[@w:styleId='Boxed']/w:pPr/w:pBdr/*", ns).map(&:name)).to eq %w(top left bottom right) }
  end

  describe 'cell with a border color only' do
    let(:xml) { document_xml { |docx| docx.table(data) { cell_style rows[0][0], border_color: 'ff0000' } } }

    it { expect(xml.xpath('//w:tcBorders/w:top', ns).map { |n| attrs n }).to eq [{ 'val' => 'single', 'sz' => '4', 'space' => '0', 'color' => 'ff0000' }] }
  end
end
