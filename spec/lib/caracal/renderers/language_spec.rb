require 'spec_helper'

describe 'language rendering' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  def document_xml(docx)
    Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(docx)
  end

  def styles_xml(docx)
    Nokogiri::XML Caracal::Renderers::StylesRenderer.render(docx)
  end

  def langs(xml, path)
    xml.xpath("#{path}/w:rPr/w:lang/@w:val", ns).map(&:value)
  end

  describe 'runs, links and paragraphs' do
    let(:xml) do
      document_xml(Caracal::Document.new do |docx|
        docx.p lang: 'de-DE' do
          text 'Absatz, '
          text 'run, ', lang: 'en-GB'
          link 'lien', 'https://example.com', lang: 'fr-FR'
          field :page
        end
        docx.p 'no language'
      end)
    end

    it { expect(langs xml, '//w:body/w:p[1]/w:r').to eq %w(de-DE en-GB de-DE de-DE de-DE de-DE) }
    it { expect(langs xml, '//w:hyperlink/w:r').to eq %w(fr-FR) }
    it { expect(langs xml, '//w:body/w:p[1]/w:pPr').to eq %w(de-DE) }
    it { expect(xml.xpath('//w:body/w:p[2]//w:lang', ns)).to be_empty }
  end

  it 'sets the language of list items and table cells' do
    docx = Caracal::Document.new
    docx.ul { li 'Punkt', lang: 'de-DE' }
    docx.table [[Caracal::Core::Models::TableCellModel.new(content: 'cel', lang: 'nl-NL')]]
    xml = document_xml docx

    expect(langs xml, '//w:body/w:p/w:r').to eq %w(de-DE)
    expect(langs xml, '//w:tc/w:p/w:r').to eq %w(nl-NL)
  end

  # CT_RPr: ... vertAlign, rtl, cs, em, lang, eastAsianLayout, specVanish, oMath
  it 'writes lang after rtl and before specVanish' do
    docx = Caracal::Document.new
    docx.p 'x', lang: 'he-IL', rtl: true, vertical_align: :superscript, hide_mark: true, color: 'ff0000'

    expect(document_xml(docx).xpath('//w:pPr/w:rPr/*', ns).map(&:name)).to eq %w(vanish color vertAlign rtl lang specVanish)
  end

  describe 'styles' do
    let(:docx) do
      Caracal::Document.new do |docx|
        docx.style id: 'German',  name: 'german',  lang: 'de-DE'
        docx.style id: 'French',  name: 'french',  lang: 'fr-FR', type: 'character'
        docx.style id: 'Dutch',   name: 'dutch',   lang: 'nl-NL', type: 'table'
      end
    end
    let(:xml) { styles_xml docx }

    it { expect(langs xml, "//w:style[@w:styleId='German']").to eq %w(de-DE) }
    it { expect(langs xml, "//w:style[@w:styleId='French']").to eq %w(fr-FR) }
    it { expect(langs xml, "//w:style[@w:styleId='Dutch']").to eq %w(nl-NL) }
    it { expect(langs xml, '//w:docDefaults/w:rPrDefault').to be_empty }
  end

  describe 'document language' do
    let(:docx) { Caracal::Document.new }

    it 'renders into the document defaults' do
      docx.language 'en-GB'

      expect(langs styles_xml(docx), '//w:docDefaults/w:rPrDefault').to eq %w(en-GB)
    end

    it 'leaves the default paragraph style without a language' do
      docx.language 'en-GB'

      expect(langs styles_xml(docx), "//w:style[@w:styleId='Normal']").to be_empty
    end

    it 'renders the default style language into the document defaults' do
      docx.style id: 'Normal', name: 'normal', font: 'Arial', size: 20, lang: 'de-DE'

      expect(langs styles_xml(docx), '//w:docDefaults/w:rPrDefault').to eq %w(de-DE)
    end

    it 'takes precedence over the default style in the document defaults' do
      docx.style id: 'Normal', name: 'normal', font: 'Arial', size: 20, lang: 'de-DE'
      docx.language 'en-GB'
      xml = styles_xml docx

      expect(langs xml, '//w:docDefaults/w:rPrDefault').to eq %w(en-GB)
      expect(langs xml, "//w:style[@w:styleId='Normal']").to eq %w(de-DE)
    end

    it { expect(docx.language).to be_nil }
    it { expect(Caracal::Document.new { language 'de-CH' }.language).to eq 'de-CH' }

    it 'is set by assignment' do
      docx.language = 'sr-Latn-RS'

      expect(docx.language).to eq 'sr-Latn-RS'
    end
  end

  describe 'validation' do
    let(:docx) { Caracal::Document.new }

    it { expect { docx.language 'en_GB' }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.language = '' }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.p 'x', lang: 'en GB' }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.p { text 'x', lang: 'de_DE' } }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.p { link 'x', 'y', lang: 'fr_FR' } }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.style id: 'X', name: 'x', lang: 'nl_NL' }.to raise_error Caracal::Errors::InvalidModelError }
    it { expect { docx.p 'x', lang: 'zh-Hant-TW' }.not_to raise_error }
  end
end
