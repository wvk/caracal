require 'spec_helper'

describe 'headers and footers' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }

  # renders the document and returns its parts by name
  def parts(document)
    zip = Zip::File.open_buffer document.render.string
    zip.entries.to_h {|entry| [entry.name, entry.get_input_stream.read] }
  end

  def xml(document, name)
    Nokogiri::XML parts(document).fetch(name)
  end

  def texts(node)
    node.xpath('//w:t', ns).map(&:text)
  end

  describe 'header contents' do
    it 'evaluates the block form' do
      docx = Caracal::Document.new { header { p 'from block' } }
      expect(texts xml(docx, 'word/header1.xml')).to eq ['from block']
    end

    it 'evaluates a block with an explicit argument' do
      docx = Caracal::Document.new {|d| d.header {|h| h.p 'from block' } }
      expect(texts xml(docx, 'word/header1.xml')).to eq ['from block']
    end

    it 'evaluates a block on an existing header' do
      docx = Caracal::Document.new do
        header.p 'first'
        header { p 'second' }
      end
      expect(texts xml(docx, 'word/header1.xml')).to eq %w(first second)
    end

    it 'renders all contents in order, keeping their alignment' do
      docx = Caracal::Document.new do
        header do
          p 'one', align: :right
          p 'two'
          p 'three', align: :center
        end
      end
      header = xml docx, 'word/header1.xml'
      expect(texts header).to eq %w(one two three)
      expect(header.xpath('//w:p/w:pPr/w:jc/@w:val', ns).map(&:value)).to eq %w(right center)
    end

    it 'ends with a paragraph after a table' do
      docx = Caracal::Document.new { header.table [['a', 'b']] }
      header = xml docx, 'word/header1.xml'
      expect(header.root.elements.map(&:name)).to eq %w(tbl p)
    end

    it 'renders an empty paragraph when empty' do
      docx = Caracal::Document.new { header }
      header = xml docx, 'word/header1.xml'
      expect(header.root.elements.map(&:name)).to eq %w(p)
      expect(header.at_xpath('//w:pStyle/@w:val', ns).value).to eq 'Header'
    end
  end

  describe 'footer contents' do
    it 'evaluates the block form and renders all contents in order' do
      docx = Caracal::Document.new do
        footer.p 'left', align: :left
        footer { p 'plain' }
      end
      footer = xml docx, 'word/footer1.xml'
      expect(footer.root.name).to eq 'ftr'
      expect(texts footer).to eq %w(left plain)
    end

    it 'writes the relationships of footer images' do
      docx = Caracal::Document.new { footer.img 'https://example.com/a.png', data: 'png', width: 10, height: 10 }
      rels = Nokogiri::XML(parts(docx).fetch 'word/_rels/footer1.xml.rels').remove_namespaces!
      expect(rels.xpath('//Relationship/@Type').map(&:value)).to all end_with '/image'
      expect(rels.xpath('//Relationship').size).to eq 1
    end
  end

  describe 'page numbers' do
    def footer_rels(docx)
      rels = Nokogiri::XML(parts(docx).fetch 'word/_rels/document.xml.rels').remove_namespaces!
      rels.xpath("//Relationship[contains(@Type, '/footer')]/@Target").map(&:value)
    end

    def page_number_paragraph(docx)
      xml(docx, 'word/footer1.xml').xpath('//w:p', ns).last
    end

    it 'renders no footer by default' do
      docx = Caracal::Document.new { p 'body' }
      expect(parts(docx).keys).not_to include 'word/footer1.xml'
      expect(footer_rels docx).to be_empty
    end

    it 'renders no footer when switched off' do
      docx = Caracal::Document.new { page_numbers false }
      expect(parts(docx).keys).not_to include 'word/footer1.xml'
    end

    it 'creates a footer holding the label and a PAGE field' do
      docx = Caracal::Document.new { page_numbers true, align: :right, label: 'Page', label_size: 24, number_size: 20 }
      expect(footer_rels docx).to eq ['footer1.xml']
      paragraph = page_number_paragraph docx
      expect(paragraph.at_xpath('w:pPr/w:jc/@w:val', ns).value).to eq 'right'
      expect(paragraph.xpath('w:r/w:t', ns).map(&:text)).to eq ['Page ']
      expect(paragraph.at_xpath('w:r[w:t]/w:rPr/w:sz/@w:val', ns).value).to eq '24'
      expect(paragraph.at_xpath('w:r/w:instrText', ns).text).to eq 'PAGE'
      expect(paragraph.at_xpath('w:r[w:instrText]/w:rPr/w:sz/@w:val', ns).value).to eq '20'
    end

    it 'centers the number without a label by default' do
      docx = Caracal::Document.new { page_numbers true }
      paragraph = page_number_paragraph docx
      expect(paragraph.at_xpath('w:pPr/w:jc/@w:val', ns).value).to eq 'center'
      expect(paragraph.xpath('w:r/w:t', ns)).to be_empty
      expect(paragraph.at_xpath('w:r/w:instrText', ns).text).to eq 'PAGE'
    end

    it 'supports the block form' do
      docx = Caracal::Document.new
      docx.page_numbers(true) { align :left; label 'Seite'; size 18 }
      paragraph = page_number_paragraph docx
      expect(paragraph.at_xpath('w:pPr/w:jc/@w:val', ns).value).to eq 'left'
      expect(paragraph.xpath('w:r/w:rPr/w:sz/@w:val', ns).map(&:value)).to eq %w(18 18)
    end

    it 'appends to footer contents regardless of call order' do
      before = Caracal::Document.new do
        page_numbers true
        footer.p 'footer text'
      end
      after = Caracal::Document.new { footer.p 'footer text' }
      after.page_numbers true
      [before, after].each do |docx|
        footer = xml docx, 'word/footer1.xml'
        expect(footer.xpath('//w:p', ns).size).to eq 2
        expect(footer.at_xpath('//w:p[1]//w:t', ns).text).to eq 'footer text'
        expect(footer.at_xpath('//w:p[2]//w:instrText', ns).text).to eq 'PAGE'
        expect(footer_rels docx).to eq ['footer1.xml']
      end
    end

    it 'renders page numbers once when rendered twice' do
      docx = Caracal::Document.new { page_numbers true }
      docx.render
      expect(xml(docx, 'word/footer1.xml').xpath('//w:instrText', ns).size).to eq 1
    end
  end

  describe 'content types' do
    def overrides(docx)
      types = Nokogiri::XML(parts(docx).fetch '[Content_Types].xml').remove_namespaces!
      types.xpath('//Override/@PartName').map(&:value).grep(%r{/word/(header|footer)})
    end

    it 'declares no header or footer parts when there are none' do
      expect(overrides Caracal::Document.new).to be_empty
    end

    it 'declares the existing header and footer parts' do
      docx = Caracal::Document.new { header.p 'h'; footer.p 'f' }
      expect(overrides docx).to eq %w(/word/header1.xml /word/footer1.xml)
    end
  end
end
