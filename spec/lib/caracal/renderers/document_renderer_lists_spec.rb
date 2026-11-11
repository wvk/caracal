require 'spec_helper'

describe Caracal::Renderers::DocumentRenderer do
  let(:ns)  { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:xml) { Nokogiri::XML described_class.render(document) }

  describe 'list item alignment' do
    let(:document) do
      Caracal::Document.new do |docx|
        docx.ul do
          li 'centered', align: :center
          li 'plain'
          li 'right', bold: true do
            align :right
          end
        end
      end
    end

    let(:items) { xml.xpath('//w:p[w:pPr/w:numPr]', ns) }

    it { expect(items.map {|p| p.at_xpath('w:pPr/w:jc/@w:val', ns)&.value }).to eq ['center', nil, 'right'] }
    it { expect(items[2].xpath('w:pPr/*', ns).map(&:name).last(3)).to eq %w(contextualSpacing jc rPr) }
  end
end
