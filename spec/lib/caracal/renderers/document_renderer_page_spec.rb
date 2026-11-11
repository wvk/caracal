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
end
