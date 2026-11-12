require 'spec_helper'

describe 'table styles' do
  let(:ns)     { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:xml)    { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(document) }
  let(:styles) { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(document) }
  let(:rows)   { xml.xpath('//w:tbl/w:tr', ns) }

  def run_props(row, name)
    row.xpath('w:tc', ns).map { |tc| not tc.at_xpath(".//w:r/w:rPr/w:#{name}", ns).nil? }
  end

  describe 'without conditional formats' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.style id: 'Plain', name: 'plain', type: :table, color: '333399'
        docx.table [%w(a b), %w(c d)], style: 'Plain'
      end
    end

    it { expect(xml.at_xpath('//w:tblPr/w:tblStyle/@w:val', ns).value).to eq 'Plain' }
    it { expect(xml.xpath('//w:tc//w:r/w:rPr/w:color/@w:val', ns).map(&:value)).to eq %w(333399) * 4 }
    it { expect(styles.at_xpath("//w:style[@w:styleId='Plain']/w:tblStylePr", ns)).to be_nil }
  end

  describe 'with conditional formats' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.style id: 'Grid', name: 'grid', type: :table do
          conditional_format type: :firstRow, bold: true, bgcolor: 'cccccc'
          conditional_format type: :lastRow, italic: true
          conditional_format type: :firstCol, color: 'aa0000'
          conditional_format type: :lastCol, underline: true
          conditional_format type: :band2Horz, strike: true
          conditional_format(type: :band1Horz) { caps true }
        end
        docx.table [%w(H1 H2 H3), %w(a b c), %w(d e f), %w(T1 T2 T3)], style: 'Grid' do
          look first_row: true, last_row: true, first_col: true, last_col: true
        end
      end
    end

    it { expect(styles.xpath("//w:style[@w:styleId='Grid']/w:tblStylePr/@w:type", ns).map(&:value)).to eq %w(firstRow lastRow firstCol lastCol band2Horz band1Horz) }
    it { expect(styles.at_xpath("//w:style[@w:styleId='Grid']/w:tblStylePr[@w:type='firstRow']/w:tcPr/w:shd/@w:color", ns).value).to eq 'cccccc' }

    it { expect(run_props rows[0], 'b').to eq [true, true, true] }
    it { expect(run_props rows[1], 'b').to eq [false, false, false] }
    it { expect(run_props rows[3], 'i').to eq [true, true, true] }
    it { expect(rows.map { |r| run_props(r, 'color').first }).to eq [true, true, true, true] }
    it { expect(rows.map { |r| run_props(r, 'u').last }).to eq [true, true, true, true] }
    it { expect(rows.map { |r| run_props(r, 'caps')[1] }).to eq [false, true, false, false] }
    it { expect(rows.map { |r| run_props(r, 'strike')[1] }).to eq [false, false, true, false] }

    # firstRow lastRow firstCol lastCol band1Vert band2Vert band1Horz band2Horz nwCell neCell swCell seCell
    it { expect(rows[0].xpath('w:tc/w:tcPr/w:cnfStyle/@w:val', ns).map(&:value)).to eq %w(101000001000 100010000000 100100000100) }
    it { expect(rows[1].xpath('w:tc/w:tcPr/w:cnfStyle/@w:val', ns).map(&:value)).to eq %w(001000100000 000010100000 000100100000) }
    it { expect(rows[3].xpath('w:tc/w:tcPr/w:cnfStyle/@w:val', ns).map(&:value)).to eq %w(011000000010 010010000000 010100000001) }
  end

  describe 'conditional format precedence' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.style id: 'Grid', name: 'grid', type: :table, color: '111111' do
          conditional_format type: :firstRow, color: '222222'
          conditional_format type: :band1Horz, color: '333333'
          conditional_format type: :wholeTable, color: '444444'
        end
        docx.table [%w(a), %w(b), %w(c)], style: 'Grid' do
          look first_row: true
        end
      end
    end

    it { expect(xml.xpath('//w:tc//w:r/w:rPr/w:color/@w:val', ns).map(&:value)).to eq %w(222222 333333 444444) }
  end

  describe 'conditional_format' do
    let(:style) { Caracal::Core::Models::TableStyleModel.new id: 'T', name: 't', type: :table }

    it { expect { style.conditional_format type: 'lastCol', bold: true }.not_to raise_error }
    it { expect(style.tap { |s| s.conditional_format type: 'lastCol' }.find_conditional_format(:lastCol)).not_to be_nil }
    it { expect { style.conditional_format type: :middle }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect(style.find_conditional_format :firstRow).to be_nil }
  end
end
