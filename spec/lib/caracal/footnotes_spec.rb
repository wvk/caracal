require 'spec_helper'

describe 'footnotes' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'r' => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' } }

  # renders the document and returns its parts by name
  def parts(document)
    zip = Zip::File.open_buffer document.render.string
    zip.entries.to_h {|entry| [entry.name, entry.get_input_stream.read] }
  end

  def xml(document, name)
    Nokogiri::XML parts(document).fetch(name)
  end

  def rels(document, name)
    Nokogiri::XML(parts(document).fetch name).remove_namespaces!
  end

  def notes(document)
    xml(document, 'word/footnotes.xml').xpath('//w:footnote[not(@w:type)]', ns)
  end

  def note_text(note)
    note.xpath('.//w:t', ns).map(&:text).join
  end

  let(:docx) do
    Caracal::Document.new do
      p do
        text 'A claim'
        footnote { text 'Its source, '; link 'with a link', 'https://example.com/' }
      end
    end
  end

  describe 'without footnotes' do
    let(:docx) { Caracal::Document.new { p 'No notes.' } }

    it 'writes no footnotes part' do
      names = parts(docx).keys
      expect(names).not_to include 'word/footnotes.xml', 'word/_rels/footnotes.xml.rels'
      expect(xml(docx, '[Content_Types].xml').to_s).not_to include 'footnotes'
      expect(rels(docx, 'word/_rels/document.xml.rels').xpath("//Relationship[contains(@Type, '/footnotes')]")).to be_empty
      expect(xml(docx, 'word/settings.xml').at_xpath('//w:footnotePr', ns)).to be_nil
    end
  end

  describe 'package' do
    it 'writes the footnotes part with its relationship and content type' do
      types  = Nokogiri::XML(parts(docx).fetch '[Content_Types].xml').remove_namespaces!
      target = rels(docx, 'word/_rels/document.xml.rels').at_xpath("//Relationship[@Type='http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes']/@Target")

      expect(target.value).to eq 'footnotes.xml'
      expect(types.at_xpath("//Override[@PartName='/word/footnotes.xml']/@ContentType").value).to eq 'application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml'
    end

    it 'names the separators in the settings' do
      settings = xml docx, 'word/settings.xml'
      expect(settings.xpath('//w:footnotePr/w:footnote/@w:id', ns).map(&:value)).to eq %w(-1 0)
      expect(settings.at_xpath('//w:footnotePr/following-sibling::*[1]', ns).name).to eq 'compat'
    end

    it 'starts the footnotes with the separator and continuation separator' do
      footnotes = xml docx, 'word/footnotes.xml'
      separators = footnotes.xpath('//w:footnote[@w:type]', ns)

      expect(separators.map {|f| [f['w:type'], f['w:id']] }).to eq [%w(separator -1), %w(continuationSeparator 0)]
      expect(separators.map {|f| f.at_xpath('w:p/w:r/*', ns).name }).to eq %w(separator continuationSeparator)
    end

    it 'renders the same twice' do
      first, second = 2.times.map { parts(docx).values_at 'word/document.xml', 'word/footnotes.xml', 'word/_rels/document.xml.rels', 'word/_rels/footnotes.xml.rels' }
      expect(second).to eq first
    end

    it 'drops the footnotes part once the footnotes are gone' do
      parts docx
      docx.contents.clear
      docx.p 'No notes.'

      expect(parts(docx).keys).not_to include 'word/footnotes.xml'
      expect(rels(docx, 'word/_rels/document.xml.rels').xpath("//Relationship[contains(@Type, '/footnotes')]")).to be_empty
    end
  end

  describe 'references' do
    let(:docx) do
      Caracal::Document.new do
        p do
          text 'First'
          footnote 'one'
          text ' second'
          footnote 'two'
        end
        ul do
          li do
            text 'item'
            footnote 'three'
            ul { li { text 'nested'; footnote 'four' } }
            text 'after the nested list'
            footnote 'five'
          end
        end
        table [[Caracal::Core::Models::TableCellModel.new { p { text 'cell'; footnote 'six' } }]]
        h2 { text 'Heading'; footnote 'seven' }
      end
    end

    it 'numbers the footnotes in the order of their references' do
      ids = xml(docx, 'word/document.xml').xpath('//w:footnoteReference/@w:id', ns).map(&:value)
      expect(ids).to eq %w(1 2 3 4 5 6 7)
      expect(notes(docx).map {|note| [note['w:id'], note_text(note)] }).to eq [
        ['1', ' one'], ['2', ' two'], ['3', ' three'], ['4', ' four'], ['5', ' five'], ['6', ' six'], ['7', ' seven']
      ]
    end

    it 'writes each reference as a run in the FootnoteReference style where it is called' do
      paragraph = xml(docx, 'word/document.xml').at_xpath('//w:body/w:p', ns)
      runs = paragraph.xpath('w:r', ns)

      expect(runs.map {|r| r.at_xpath('w:t|w:footnoteReference', ns).name }).to eq %w(t footnoteReference t footnoteReference)
      expect(runs[1].at_xpath('w:rPr/w:rStyle/@w:val', ns).value).to eq 'FootnoteReference'
    end

    it 'follows the text given to p' do
      docx = Caracal::Document.new { p('A claim') { footnote 'Its source.' } }
      runs = xml(docx, 'word/document.xml').xpath('//w:body/w:p/w:r', ns)

      expect(runs.map {|r| r.elements.last.name }).to eq %w(t footnoteReference)
      expect(runs.first.at_xpath('w:t', ns).text).to eq 'A claim'
      expect(runs.last.at_xpath('w:footnoteReference/@w:id', ns).value).to eq '1'
    end

    it 'formats the reference like its paragraph, keeping it raised' do
      docx = Caracal::Document.new { p(size: 36, vertical_align: :subscript) { text 'Big'; footnote 'note' } }
      rpr  = xml(docx, 'word/document.xml').at_xpath('//w:r[w:footnoteReference]/w:rPr', ns)

      expect(rpr.at_xpath('w:sz/@w:val', ns).value).to eq '36'
      expect(rpr.at_xpath('w:vertAlign', ns)).to be_nil
    end

    it 'leaves footnotes out of headers and footers' do
      docx = Caracal::Document.new { header { p { text 'Head'; footnote 'not here' } } }
      header = xml docx, 'word/header1.xml'

      expect(header.at_xpath('//w:footnoteReference', ns)).to be_nil
      expect(parts(docx).keys).not_to include 'word/footnotes.xml'
    end
  end

  describe 'footnote text' do
    let(:note) { notes(docx).first }

    it 'is a paragraph in the FootnoteText style opening with the mark' do
      paragraph = note.at_xpath('w:p', ns)
      mark      = paragraph.at_xpath('w:r[1]', ns)

      expect(paragraph.at_xpath('w:pPr/w:pStyle/@w:val', ns).value).to eq 'FootnoteText'
      expect(mark.at_xpath('w:footnoteRef', ns)).not_to be_nil
      expect(mark.at_xpath('w:rPr/w:rStyle/@w:val', ns).value).to eq 'FootnoteReference'
      expect(note_text note).to eq ' Its source, with a link'
    end

    it 'holds formatted runs' do
      docx = Caracal::Document.new do
        p do
          text 'Claim'
          footnote('Plain, ', color: '666666') { text 'bold', bold: true; text ' and '; text 'italic', italic: true }
        end
      end
      runs = notes(docx).first.xpath('.//w:r[w:t]', ns)

      expect(runs.map {|r| r.at_xpath('w:t', ns).text }).to eq [' ', 'Plain, ', 'bold', ' and ', 'italic']
      expect(runs[2].at_xpath('w:rPr/w:b/@w:val', ns).value).to eq 'true'
      expect(runs[4].at_xpath('w:rPr/w:i/@w:val', ns).value).to eq 'true'
      expect(runs.map {|r| r.at_xpath('w:rPr/w:color/@w:val', ns)&.value }.uniq).to eq ['666666']
    end

    it 'does not take the formatting of the paragraph it annotates' do
      docx = Caracal::Document.new { p(bold: true) { text 'Claim'; footnote 'Source' } }
      expect(notes(docx).first.at_xpath('.//w:b', ns)).to be_nil
    end

    it 'points its links into the relationships of the footnotes part' do
      link   = notes(docx).first.at_xpath('.//w:hyperlink', ns)
      target = rels(docx, 'word/_rels/footnotes.xml.rels').at_xpath("//Relationship[@Id='#{link.attribute_with_ns('id', ns['r']).value}']")

      expect(target['Target']).to eq 'https://example.com/'
      expect(target['TargetMode']).to eq 'External'
      expect(rels(docx, 'word/_rels/document.xml.rels').to_s).not_to include 'example.com'
    end

    it 'writes no relationships part for footnotes without links' do
      docx = Caracal::Document.new { p { text 'Claim'; footnote 'Source' } }
      expect(parts(docx).keys).to include 'word/footnotes.xml'
      expect(parts(docx).keys).not_to include 'word/_rels/footnotes.xml.rels'
    end

    it 'cannot contain footnotes' do
      expect { Caracal::Document.new { p { footnote { footnote 'nested' } } } }.to raise_error(Caracal::Errors::InvalidModelError)
    end
  end

  describe 'styles' do
    def style(docx, id)
      xml(docx, 'word/styles.xml').at_xpath("//w:style[@w:styleId='#{id}']", ns)
    end

    it 'defines FootnoteText and FootnoteReference' do
      expect(style(docx, 'FootnoteText')['w:type']).to eq 'paragraph'
      expect(style(docx, 'FootnoteText').at_xpath('w:name/@w:val', ns).value).to eq 'footnote text'
      expect(style(docx, 'FootnoteReference')['w:type']).to eq 'character'
      expect(style(docx, 'FootnoteReference').at_xpath('w:rPr/w:vertAlign/@w:val', ns).value).to eq 'superscript'
    end

    it 'lets them be overridden' do
      docx = Caracal::Document.new do
        style id: 'FootnoteText', name: 'footnote text', size: 14, italic: true
        style id: 'FootnoteReference', name: 'footnote reference', type: :character, color: 'cc0000', vertical_align: :superscript
        p { text 'Claim'; footnote 'Source' }
      end

      expect(xml(docx, 'word/styles.xml').xpath("//w:style[@w:styleId='FootnoteText']", ns).size).to eq 1
      expect(style(docx, 'FootnoteText').at_xpath('w:rPr/w:sz/@w:val', ns).value).to eq '14'
      expect(style(docx, 'FootnoteReference').at_xpath('w:rPr/w:color/@w:val', ns).value).to eq 'cc0000'
    end
  end
end
