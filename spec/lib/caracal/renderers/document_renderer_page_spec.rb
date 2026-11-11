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
end
