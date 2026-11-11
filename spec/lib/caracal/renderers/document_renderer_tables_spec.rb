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

  describe 'table widths' do
    let(:rows)      { xml.xpath('//w:tbl/w:tr', ns) }
    let(:grid)      { xml.xpath('//w:tblGrid/w:gridCol/@w:w', ns).map {|w| w.value.to_i } }
    let(:tbl_width) { xml.at_xpath('//w:tblPr/w:tblW/@w:w', ns).value.to_i }

    def tc_widths(row)
      row.xpath('w:tc/w:tcPr/w:tcW', ns).map {|tc_w| [tc_w['w:w'].to_i, tc_w['w:type']] }
    end

    describe 'without explicit widths' do
      let(:document) { Caracal::Document.new {|docx| docx.table [['a', 'b', 'c'], ['d', 'e', 'f']] } }

      it { expect(grid).to eq [3120, 3120, 3120] }
      it { expect(rows.map {|r| tc_widths(r) }).to all eq [[3120, 'dxa']] * 3 }
    end

    describe 'with a spanning cell width' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['ab', 'c'], ['a', 'b', 'c']] do
            cell_style rows[0][0], colspan: 2, width: 4000
          end
        end
      end

      it { expect(tbl_width).to eq 9360 }
      it { expect(grid).to eq [2000, 2000, 5360] }
      it { expect(grid.sum).to eq tbl_width }
      it { expect(tc_widths(rows[0])).to eq [[4000, 'dxa'], [5360, 'dxa']] }
      it { expect(tc_widths(rows[1])).to eq [[2000, 'dxa'], [2000, 'dxa'], [5360, 'dxa']] }
    end

    describe 'with single and spanning cell widths' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['ab', 'c'], ['a', 'b', 'c']] do
            cell_style rows[0][0], colspan: 2, width: 4000
            cell_style rows[1][0], width: 1000
          end
        end
      end

      it { expect(grid).to eq [1000, 3000, 5360] }
      it { expect(tc_widths(rows[0])).to eq [[4000, 'dxa'], [5360, 'dxa']] }
    end

    describe 'with column widths' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['ab', 'c'], ['a', 'b', 'c']] do
            column_widths [1000, 2000, 3000]
            cell_style rows[0][0], colspan: 2, width: 4000
          end
        end
      end

      it { expect(grid).to eq [1000, 2000, 3000] }
      it { expect(tc_widths(rows[0])).to eq [[3000, 'dxa'], [3000, 'dxa']] }
      it { expect(tc_widths(rows[1])).to eq [[1000, 'dxa'], [2000, 'dxa'], [3000, 'dxa']] }
    end

    describe 'tcPr order' do
      let(:document) do
        Caracal::Document.new do |docx|
          docx.table [['ab', 'c'], ['a', 'b', 'c']] do
            cell_style rows[0][0], colspan: 2, rowspan: 2, bgcolor: 'cccccc', margins: { top: 100 }, content_vertical_align: :center
          end
        end
      end

      it { expect(rows[0].xpath('w:tc[1]/w:tcPr/*', ns).map(&:name)).to eq %w(tcW gridSpan vMerge shd tcMar vAlign) }
    end
  end

  describe 'conditional formatting with colspans' do
    let(:rows) { xml.xpath('//w:tbl/w:tr', ns) }
    let(:document) do
      Caracal::Document.new do |docx|
        docx.style id: 'Grid', name: 'grid', type: :table do
          conditional_format type: 'lastCol', id: 'GridLastCol', name: 'grid last col', bold: true
        end
        docx.table [['ab', 'c'], ['a', 'b', 'c'], ['a', 'bc']], style: 'Grid' do
          look first_row: true, first_col: true, last_col: true
          cell_style rows[0][0], colspan: 2
          cell_style rows[2][1], colspan: 2
        end
      end
    end

    # bitmask positions: firstRow lastRow firstCol lastCol band1Vert band2Vert band1Horz band2Horz nwCell neCell swCell seCell
    def cnf(row)
      row.xpath('w:tc/w:tcPr/w:cnfStyle/@w:val', ns).map(&:value)
    end

    it { expect(cnf(rows[0])).to eq %w(101000001000 100100000100) }
    it { expect(cnf(rows[1])).to eq %w(001000100000 000010100000 000100100000) }
    it { expect(cnf(rows[2])).to eq %w(001000010000 000100010000) }
    it { expect(rows[2].xpath('w:tc', ns).map {|tc| tc.at_xpath('.//w:r/w:rPr/w:b', ns).nil? }).to eq [true, false] }
  end

  describe 'procs as table cells' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.table [[->{ p 'lambda' }, proc { p 'proc' }, ->(cell) { cell.p 'arg' }]]
      end
    end

    it { expect(cell_texts(xml.at_xpath('//w:tbl/w:tr', ns))).to eq %w(lambda proc arg) }
  end

  describe 'table cell margins' do
    def tc_mar(tc)
      tc.xpath('w:tcPr/w:tcMar/*', ns).map {|m| [m.name, m['w:w']] }
    end

    # README "Nested Tables"
    let(:document) do
      Caracal::Document.new do |docx|
        row1 = ['Header 1', 'Header 2', 'Header 3']
        row2 = ['Cell 1', 'Cell 2', 'Cell 3']
        row3 = ['Cell 4', 'Cell 5', 'Cell 6']
        row4 = ['Footer 1', 'Footer 2', 'Footer 3']
        c1 = Caracal::Core::Models::TableCellModel.new margins: { top: 0, bottom: 100, left: 0, right: 200 } do
          table [row1, row2, row3, row4], border_size: 4 do
            cell_style rows[0],  bold: true, bgcolor: '3366cc', color: 'ffffff'
            cell_style rows[-1], bold: true,   bgcolor: 'dddddd'
            cell_style cells[3], italic: true, color: 'cc0000'
            cell_style cells,    size: 18, margins: { top: 100, bottom: 0, left: 100, right: 100 }
          end
        end
        c2 = Caracal::Core::Models::TableCellModel.new margins: { top: 0, bottom: 100, left: 0, right: 200 } do
          p 'This layout uses nested tables (the outer table has no border) to provide a caption to the table data.'
        end

        docx.table [[c1, c2]] do
          cell_style cols[0], width: 6000
        end
      end
    end

    let(:outer_cells) { xml.xpath('/w:document/w:body/w:tbl/w:tr/w:tc', ns) }
    let(:inner_cells) { xml.xpath('//w:tbl//w:tbl/w:tr/w:tc', ns) }

    it { expect(outer_cells.map {|tc| tc_mar(tc) }).to all eq [%w(top 0), %w(left 0), %w(bottom 100), %w(right 200)] }
    it { expect(inner_cells.size).to eq 12 }
    it { expect(inner_cells.map {|tc| tc_mar(tc) }).to all eq [%w(top 100), %w(left 100), %w(bottom 0), %w(right 100)] }

    describe 'when no margins given' do
      let(:document) { Caracal::Document.new {|docx| docx.table [['x']] } }

      it { expect(xml.xpath('//w:tcMar', ns)).to be_empty }
    end
  end
end
