require 'spec_helper'

describe Caracal::Renderers::DocumentRenderer do
  let(:ns)       { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:document) { Caracal::Document.new {|docx| docx.page_margins left: 720 } }
  let(:pg_mar)   { Nokogiri::XML(described_class.render(document)).at_xpath('//w:sectPr/w:pgMar', ns) }

  describe 'page margins' do
    {top: '1440', right: '1440', bottom: '1440', left: '720', header: '720', footer: '720', gutter: '0'}.each do |attr, value|
      it { expect(pg_mar["w:#{attr}"]).to eq value }
    end
  end
  describe 'page size given in steps' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.page_size width: 15840, height: 12240, orientation: :landscape
        docx.page_size height: 12000
      end
    end
    let(:pg_sz) { Nokogiri::XML(described_class.render(document)).at_xpath('//w:sectPr/w:pgSz', ns) }

    {w: '15840', h: '12000', orient: 'landscape'}.each do |attr, value|
      it { expect(pg_sz["w:#{attr}"]).to eq value }
    end
  end

  describe 'page columns' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.page_numbers true, start: 3
        docx.page_columns 2, spacing: 360
        docx.table [['x']]
        docx.hr width: 1000
        docx.p 'left'
        docx.column_break
        docx.p do
          text 'right'
          column_break
          text 'left again'
        end
      end
    end
    let(:xml)  { Nokogiri::XML(described_class.render(document)) }
    let(:cols) { xml.at_xpath('//w:sectPr/w:cols', ns) }

    it { expect([cols['w:num'], cols['w:space']]).to eq %w(2 360) }
    it { expect(cols.at_xpath('preceding-sibling::*[1]', ns).name).to eq 'pgNumType' }
    it { expect(document.page_content_width).to eq 4500 }
    it { expect(xml.at_xpath('//w:tblW/@w:w', ns).value).to eq '4500' }
    it { expect(xml.xpath('//w:body/w:p/w:r/w:br[@w:type="column"]', ns).size).to eq 2 }
    it { expect(xml.at_xpath('//w:p[w:r/w:t="right"]/w:r[2]/w:br/@w:type', ns).value).to eq 'column' }

    it 'places a rule in a column' do
      ind = xml.at_xpath('//w:p[w:pPr/w:pBdr]/w:pPr/w:ind', ns)
      expect([ind['w:start'], ind['w:end']]).to eq %w(1750 1750)
    end

    describe 'with one column' do
      let(:document) { Caracal::Document.new {|docx| docx.page_columns 1 } }

      it { expect(cols).to be_nil }
    end

    it 'rejects columns that do not fit between the margins' do
      expect { Caracal::Document.new {|docx| docx.page_columns 2, spacing: 9360 } }.to raise_error Caracal::Errors::InvalidModelError
    end

    it 'rejects a count outside 1 to 45' do
      expect { Caracal::Document.new {|docx| docx.page_columns 0 } }.to raise_error Caracal::Errors::InvalidModelError
    end
  end
end
