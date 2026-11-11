require 'spec_helper'

describe Caracal::Document do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  def texts(document)
    Nokogiri::XML(Caracal::Renderers::DocumentRenderer.render(document)).xpath('//w:t', ns).map(&:text)
  end

  describe 'block' do
    it 'accepts a lambda' do
      expect(texts described_class.new(&-> { p 'lambda' })).to eq ['lambda']
    end

    it 'passes the document to a block with an argument' do
      expect(texts described_class.new {|docx| docx.p 'argument' }).to eq ['argument']
    end
  end

  describe 'theme part' do
    let(:a)  { { 'a' => 'http://schemas.openxmlformats.org/drawingml/2006/main' } }
    let(:r)  { { 'r' => 'http://schemas.openxmlformats.org/package/2006/relationships' } }
    let(:ct) { { 'ct' => 'http://schemas.openxmlformats.org/package/2006/content-types' } }
    let(:parts) do
      zip = Zip::File.open_buffer document.render.string
      zip.entries.to_h { |e| [e.name, Nokogiri::XML(e.get_input_stream.read)] }
    end
    let(:accent1) { parts['word/theme/theme1.xml'].at_xpath('//a:accent1/a:srgbClr/@val', a).value }
    let(:theme_rels) { parts['word/_rels/document.xml.rels'].xpath("//r:Relationship[@Target='theme/theme1.xml']/@Type", r).map(&:value) }

    shared_examples 'a document with a theme part' do
      it { expect(theme_rels).to eq ['http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme'] }
      it { expect(parts['[Content_Types].xml'].at_xpath("//ct:Override[@PartName='/word/theme/theme1.xml']", ct)).not_to be_nil }
    end

    context 'without a theme definition' do
      let(:document) { described_class.new }

      it_behaves_like 'a document with a theme part'
      it { expect(accent1).to eq '00539B' }
    end

    context 'with theme definitions' do
      let(:document) do
        described_class.new do |docx|
          docx.theme { color_accent1 'FF0000' }
          docx.theme { name 'Mine' }
        end
      end

      it_behaves_like 'a document with a theme part'
      it { expect(accent1).to eq 'FF0000' }
      it { expect(parts['word/theme/theme1.xml'].at_xpath('//a:clrScheme/@name', a).value).to eq 'Mine' }
    end

    context 'with a theme color in a header' do
      let(:document) { described_class.new { |docx| docx.header.p 'h', theme_color: :accent1 } }

      it { expect(parts['word/header1.xml'].at_xpath('//w:color/@w:val', ns).value).to eq '00539B' }
    end
  end
end
