require 'spec_helper'

describe Caracal::Renderers::DocumentRenderer do
  let(:ns)  { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:xml) { Nokogiri::XML described_class.render(document) }

  def cell_texts(row)
    row.xpath('w:tc', ns).map {|tc| tc.xpath('.//w:t', ns).map(&:text).join }
  end

  def vmerges(row)
    row.xpath('w:tc', ns).map {|tc| tc.at_xpath('w:tcPr/w:vMerge/@w:val', ns)&.value }
  end

  describe 'merged table cells' do
    let(:rows) { xml.xpath('//w:tbl/w:tr', ns) }

    describe 'rowspan after a colspan in the same row' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['11', '1213', '14'], ['21', '22', '23', '24']] do
            cell_style rows[0][0], rowspan: 2
            cell_style rows[0][1], colspan: 2
            cell_style rows[0][2], rowspan: 2
          end
        end
      end

      it { expect(vmerges(rows[0])).to eq ['restart', nil, 'restart'] }
      it { expect(vmerges(rows[1])).to eq ['continue', nil, nil, 'continue'] }
      it { expect(rows[0].xpath('w:tc/w:tcPr/w:gridSpan/@w:val', ns).map(&:value)).to eq ['2'] }
    end

    describe 'rowspan' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['a', 'b'], ['c', 'd'], ['e', 'f'], ['g', 'h']] do
            cell_style rows[0][1], rowspan: 3
          end
        end
      end

      it { expect(rows.map {|r| vmerges(r)[1] }).to eq ['restart', 'continue', 'continue', nil] }
      it { expect(rows.map {|r| vmerges(r)[0] }).to eq [nil, nil, nil, nil] }
      it { expect(xml.xpath('//w:gridSpan', ns)).to be_empty }
    end

    describe 'empty cells' do
      let(:document) { Caracal::Document.new {|docx| docx.table [['', 'x']] } }

      it { expect(rows[0].xpath('w:tc', ns).map {|tc| tc.xpath('w:p', ns).size }).to eq [1, 1] }
    end
  end
end
