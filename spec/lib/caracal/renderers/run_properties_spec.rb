require 'spec_helper'

describe 'run properties rendering' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  def document_xml(&block)
    Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(Caracal::Document.new(&block))
  end

  def run_values(xml, path)
    xml.xpath("//w:body/w:p/w:r/w:rPr/#{path}", ns).map(&:value)
  end

  describe 'run options and paragraph options' do
    let(:xml) do
      document_xml do |docx|
        docx.p do
          color 'ff0000'
          size  24
          text 'red'
          text 'blue', color: '0000ff'
        end
      end
    end

    it { expect(run_values xml, 'w:color/@w:val').to eq %w(ff0000 0000ff) }
    it { expect(run_values xml, 'w:sz/@w:val').to eq %w(24 24) }
  end

  describe 'run theme colors and paragraph theme colors' do
    let(:xml) do
      document_xml do |docx|
        docx.p do
          theme_color   :accent1
          theme_bgcolor :accent2
          text 'default, '
          text 'inverted, ', theme_color: :accent2, theme_bgcolor: :accent1
          text 'default.'
        end
      end
    end

    it { expect(run_values xml, 'w:color/@w:themeColor').to eq %w(accent1 accent2 accent1) }
    it { expect(run_values xml, 'w:shd/@w:themeColor').to eq %w(accent2 accent1 accent2) }
  end

  describe 'link underline' do
    let(:xml) do
      document_xml do |docx|
        docx.p do
          link 'default', 'https://example.com'
          link 'option', 'https://example.com', underline: false
          link 'block', 'https://example.com' do
            underline false
          end
        end
      end
    end

    it { expect(xml.xpath('//w:hyperlink/w:r/w:rPr/w:u/@w:val', ns).map(&:value)).to eq %w(single none none) }
  end

  describe 'highlight color' do
    let(:xml) do
      document_xml do |docx|
        docx.p highlight_color: 'yellow', size: 24, underline: true do
          text 'paragraph'
          text 'run', highlight_color: :darkBlue
          link 'link', 'https://example.com', highlight_color: 'green'
        end
      end
    end

    it { expect(run_values xml, 'w:highlight/@w:val').to eq %w(yellow darkBlue) }
    it { expect(xml.xpath('//w:pPr/w:rPr/w:highlight/@w:val', ns).map(&:value)).to eq %w(yellow) }
    it { expect(xml.xpath('//w:hyperlink/w:r/w:rPr/w:highlight/@w:val', ns).map(&:value)).to eq %w(green) }
    it { expect(xml.xpath('//w:body/w:p/w:r[1]/w:rPr/*', ns).map(&:name)).to eq %w(sz highlight u) }

    it 'renders style highlights' do
      docx = Caracal::Document.new
      docx.style id: 'Marked', name: 'marked', highlight_color: 'cyan'
      styles = Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx)
      expect(styles.at_xpath("//w:style[@w:styleId='Marked']/w:rPr/w:highlight/@w:val", ns).value).to eq 'cyan'
    end

    it { expect { Caracal::Document.new.p 'x', highlight_color: 'ffff00' }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { Caracal::Document.new.p { text 'x', highlight_color: 'orange' } }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { Caracal::Document.new.p { link 'x', 'y', highlight_color: 'orange' } }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { Caracal::Document.new.style id: 'X', name: 'x', highlight_color: 'orange' }.to raise_error Caracal::Errors::InvalidModelError }
  end
end
