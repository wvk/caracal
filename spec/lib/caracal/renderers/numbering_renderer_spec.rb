require 'spec_helper'

describe Caracal::Renderers::NumberingRenderer do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  let(:document) do
    Caracal::Document.new do |docx|
      docx.heading_numbering do
        h1 text: '%1.'
        h2 text: '%1.%2'
      end
      docx.h1 'Introduction'
      docx.h2 'Scope'
      docx.ul { li 'item' }
      docx.ol { li 'item' }
    end
  end

  # renders the document like Document#render does: styles and document before numbering
  def render(document)
    document.reset_numbering
    {
      styles:    Nokogiri::XML(Caracal::Renderers::StylesRenderer.render(document)),
      document:  Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(document)),
      numbering: Nokogiri::XML(described_class.render(document)),
    }
  end

  let(:xml) { render document }
  let(:heading_numbering) { xml[:numbering].at_xpath('//w:abstractNum[w:name]', ns) }

  describe 'heading numbering definition' do
    it { expect(heading_numbering.at_xpath('w:multiLevelType/@w:val', ns).value).to eq 'multilevel' }
    it { expect(heading_numbering.xpath('w:lvl/@w:ilvl', ns).map(&:value)).to eq %w(0 1 2 3 4 5) }
    it { expect(heading_numbering.xpath('w:lvl/w:pStyle/@w:val', ns).map(&:value)).to eq %w(Heading1 Heading2 Heading3 Heading4 Heading5 Heading6) }
    it { expect(heading_numbering.xpath('w:lvl/w:numFmt/@w:val', ns).map(&:value)).to eq %w(decimal decimal none none none none) }
    it { expect(heading_numbering.xpath('w:lvl/w:lvlText/@w:val', ns).map(&:value)).to eq ['%1.', '%1.%2', '', '', '', ''] }
  end

  describe 'heading styles' do
    let(:heading_id) { heading_numbering['w:abstractNumId'] }

    (1..6).each do |i|
      it "links Heading#{i} to level #{i - 1}" do
        num_pr = xml[:styles].at_xpath("//w:style[@w:styleId='Heading#{i}']/w:pPr/w:numPr", ns)
        expect(num_pr.at_xpath('w:ilvl/@w:val', ns).value).to eq (i - 1).to_s
        expect(num_pr.at_xpath('w:numId/@w:val', ns).value).to eq heading_id
      end
    end

    it { expect(xml[:styles].xpath("//w:style[@w:styleId='Normal']//w:numPr", ns)).to be_empty }
  end

  shared_examples 'consistent numbering ids' do
    let(:abstract_ids) { xml[:numbering].xpath('//w:abstractNum/@w:abstractNumId', ns).map(&:value) }
    let(:num_ids)      { xml[:numbering].xpath('//w:num/@w:numId', ns).map(&:value) }
    let(:referenced)   { (xml[:document].xpath('//w:numId/@w:val', ns) + xml[:styles].xpath('//w:numId/@w:val', ns)).map(&:value).uniq }

    it { expect(abstract_ids).to eq abstract_ids.uniq }
    it { expect(abstract_ids.size).to eq 3 }
    it { expect(num_ids).to match_array abstract_ids }
    it { expect(xml[:numbering].xpath('//w:num/w:abstractNumId/@w:val', ns).map(&:value)).to eq num_ids }
    it { expect(referenced).to match_array num_ids }
  end

  describe 'numbering ids' do
    it_behaves_like 'consistent numbering ids'
  end

  describe 'numbering ids when rendered a second time' do
    before { render document }

    it_behaves_like 'consistent numbering ids'
  end

  describe 'without heading numbering' do
    let(:document) { Caracal::Document.new {|docx| docx.h1 'Introduction' } }

    it { expect(xml[:numbering].xpath('//w:abstractNum', ns)).to be_empty }
    it { expect(xml[:styles].xpath('//w:numPr', ns)).to be_empty }
  end
end
