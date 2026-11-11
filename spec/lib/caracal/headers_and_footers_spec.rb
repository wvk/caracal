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
end
