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

    it 'numbers lists through the document' do
      docx = Caracal::Document.new do
        header.ul { li 'header item' }
        ol { li 'body item' }
      end
      num_id   = ->(part) { xml(docx, part).at_xpath('//w:numPr/w:numId/@w:val', ns).value }
      numbered = xml(docx, 'word/numbering.xml').xpath('//w:num/@w:numId', ns).map(&:value)
      expect(texts xml(docx, 'word/header1.xml')).to eq ['header item']
      expect(numbered).to include num_id['word/header1.xml'], num_id['word/document.xml']
      expect(num_id['word/header1.xml']).not_to eq num_id['word/document.xml']
    end

    it 'renders bookmarks and raw xml' do
      docx = Caracal::Document.new do
        header do
          bookmark_start id: 'h', name: 'head'
          p 'head'
          bookmark_end id: 'h'
          raw_xml '<w:p><w:r><w:t>raw</w:t></w:r></w:p>'
        end
      end
      header = xml docx, 'word/header1.xml'
      expect(header.root.elements.map(&:name)).to eq %w(bookmarkStart p bookmarkEnd p)
      expect(header.xpath('//w:bookmarkStart/@w:id | //w:bookmarkEnd/@w:id', ns).map(&:value)).to eq %w(1 1)
      expect(texts header).to eq %w(head raw)
    end

    it 'renders an empty paragraph when empty' do
      docx = Caracal::Document.new { header }
      header = xml docx, 'word/header1.xml'
      expect(header.root.elements.map(&:name)).to eq %w(p)
      expect(header.at_xpath('//w:pStyle/@w:val', ns).value).to eq 'Header'
    end
  end

  describe 'drawing ids' do
    let(:wp) { { 'wp' => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing' } }
    let(:docx) do
      Caracal::Document.new do
        header.img 'https://example.com/h.png', data: 'png', width: 10, height: 10
        footer.img 'https://example.com/f.png', data: 'png', width: 10, height: 10
        img 'https://example.com/b.png', data: 'png', width: 10, height: 10
      end
    end

    def doc_pr_ids(rendered)
      %w(word/header1.xml word/footer1.xml word/document.xml).flat_map do |name|
        Nokogiri::XML(rendered.fetch name).xpath('//wp:docPr/@id', wp).map(&:value)
      end
    end

    it 'are unique across all parts' do
      expect(doc_pr_ids(parts docx).sort).to eq %w(1 2 3)
    end

    it 'restart with each rendering' do
      parts docx
      expect(doc_pr_ids(parts docx).sort).to eq %w(1 2 3)
    end
  end

  describe 'bookmark ids' do
    let(:docx) do
      Caracal::Document.new do
        header { bookmark_start id: 'h', name: 'head'; p 'head'; bookmark_end id: 'h' }
        footer { bookmark_start id: 'f', name: 'foot'; p 'foot'; bookmark_end id: 'f' }
        bookmark_start id: 'b', name: 'body'
        p 'body'
        bookmark_end id: 'b'
      end
    end

    def bookmark_ids(rendered)
      %w(word/header1.xml word/footer1.xml word/document.xml).map do |name|
        Nokogiri::XML(rendered.fetch name).xpath('//w:bookmarkStart/@w:id', ns).map(&:value)
      end
    end

    it 'are unique across all parts' do
      expect(bookmark_ids(parts docx).flatten.sort).to eq %w(1 2 3)
    end

    it 'restart with each rendering' do
      parts docx
      expect(bookmark_ids(parts docx).flatten.sort).to eq %w(1 2 3)
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

  describe 'iframes' do
    let(:w14) { 'http://schemas.microsoft.com/office/word/2010/wordml' }

    # a Caracal document made to look like Word output: w14 namespace and w14:paraId
    let(:snippet) do
      files = parts Caracal::Document.new { p 'from word' }
      files['word/document.xml'] = files['word/document.xml']
        .sub('<w:document ', %(<w:document xmlns:w14="#{ w14 }" mc:Ignorable="w14" ))
        .sub('<w:p>', '<w:p w14:paraId="1A2B3C4D">')
      Zip::OutputStream.write_buffer {|zip| files.each {|name, content| zip.put_next_entry name; zip.write content } }.string
    end

    def expect_declared(part)
      expect(part.errors).to be_empty
      expect(part.root.namespaces).to include 'xmlns:w14' => w14
      expect(part.root['mc:Ignorable']).to eq 'w14'
      expect(part.at_xpath('//w:p[@w14:paraId="1A2B3C4D"]', ns.merge('w14' => w14))).not_to be_nil
      expect(texts part).to eq ['from word']
    end

    %i(header footer).each do |kind|
      describe "in a #{ kind }" do
        it 'declares the namespaces and ignorables of the embedded document' do
          data = snippet
          docx = Caracal::Document.new {|d| d.send(kind).iframe data: data }
          expect_declared xml(docx, "word/#{ kind }1.xml")
        end

        it 'declares them for an iframe in a table cell' do
          data = snippet
          cell = Caracal::Core::Models::TableCellModel.new {|c| c.iframe data: data }
          docx = Caracal::Document.new {|d| d.send(kind).table [[cell]] }
          expect_declared xml(docx, "word/#{ kind }1.xml")
        end

        it 'declares them on a first page showing the default content' do
          data = snippet
          docx = Caracal::Document.new {|d| d.send(kind).iframe data: data; d.page_numbers true, first_page: false }
          expect_declared xml(docx, "word/#{ kind }2.xml")
        end
      end
    end

    it 'leaves the default namespaces of a part without iframes' do
      part = xml Caracal::Document.new { header.p 'h' }, 'word/header1.xml'
      expect(part.root.namespaces.keys).to eq Caracal::Header.default_namespaces.map {|namespace| namespace[:prefix] }
      expect(part.root['mc:Ignorable']).to be_nil
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
      expect(paragraph.at_xpath('w:r/w:instrText', ns).text.strip).to eq 'PAGE'
      expect(paragraph.at_xpath('w:r[w:instrText]/w:rPr/w:sz/@w:val', ns).value).to eq '20'
    end

    it 'centers the number without a label by default' do
      docx = Caracal::Document.new { page_numbers true }
      paragraph = page_number_paragraph docx
      expect(paragraph.at_xpath('w:pPr/w:jc/@w:val', ns).value).to eq 'center'
      expect(paragraph.xpath('w:r/w:t', ns)).to be_empty
      expect(paragraph.at_xpath('w:r/w:instrText', ns).text.strip).to eq 'PAGE'
    end

    it 'supports the block form' do
      docx = Caracal::Document.new
      docx.page_numbers(true) { align :left; label 'Seite'; size 18 }
      paragraph = page_number_paragraph docx
      expect(paragraph.at_xpath('w:pPr/w:jc/@w:val', ns).value).to eq 'left'
      expect(paragraph.xpath('w:r/w:rPr/w:sz/@w:val', ns).map(&:value)).to eq %w(18 18 18 18 18)  # label and the four field runs
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
        expect(footer.at_xpath('//w:p[2]//w:instrText', ns).text.strip).to eq 'PAGE'
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

  describe 'first page' do
    let(:r)     { 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' }
    let(:sect)  { xml(docx, 'word/document.xml').at_xpath('//w:body/w:sectPr', ns) }

    def references(sect, kind)
      sect.xpath("w:#{kind}Reference", ns).map {|ref| ref['w:type'] }
    end

    # maps reference type to the referenced part's texts
    def referenced_texts(docx, sect, kind)
      rels = Nokogiri::XML(parts(docx).fetch 'word/_rels/document.xml.rels').remove_namespaces!
      sect.xpath("w:#{kind}Reference", ns).to_h do |ref|
        target = rels.at_xpath("//Relationship[@Id='#{ref.attribute_with_ns('id', r).value}']/@Target").value
        [ref['w:type'], texts(xml(docx, "word/#{target}"))]
      end
    end

    describe 'by default' do
      let(:docx) { Caracal::Document.new { header.p 'h'; footer.p 'f' } }

      it { expect(sect.at_xpath('w:titlePg', ns)).to be_nil }
      it { expect(references sect, 'header').to eq %w(default) }
      it { expect(references sect, 'footer').to eq %w(default) }
    end

    describe 'without headers and footers' do
      let(:docx) { Caracal::Document.new }

      it { expect(sect.element_children.map(&:name)).to eq %w(pgSz pgMar) }
    end

    describe 'with the page number off the first page' do
      let(:docx) { Caracal::Document.new { header.p 'h'; page_numbers true, first_page: false } }

      it { expect(sect.element_children.map(&:name)).to eq %w(headerReference headerReference footerReference pgSz pgMar titlePg) }
      it { expect(referenced_texts docx, sect, 'header').to eq 'default' => ['h'], 'first' => ['h'] }
      it { expect(references sect, 'footer').to eq %w(default) }
    end

    describe 'with a blank first page' do
      let(:docx) do
        Caracal::Document.new do
          header.p 'h'
          footer.p 'f'
          header first: true
          footer first: true
          page_numbers true, first_page: false
        end
      end

      it { expect(sect.at_xpath('w:titlePg', ns)).not_to be_nil }
      it { expect(referenced_texts docx, sect, 'header').to eq 'default' => ['h'] }
      it { expect(referenced_texts docx, sect, 'footer').to eq 'default' => ['f'] }
      it { expect(parts(docx).keys).not_to include('word/header2.xml', 'word/footer2.xml') }
    end

    describe 'with a first page header and page numbers' do
      let(:docx) { Caracal::Document.new { header(first: true) { p 'cover' }; page_numbers true } }

      it { expect(sect.at_xpath('w:titlePg', ns)).not_to be_nil }
      it { expect(references(sect, 'footer').sort).to eq %w(default first) }
      it { expect(xml(docx, 'word/footer2.xml').xpath('//w:instrText', ns)).not_to be_empty }
    end

    describe 'with first page header and footer' do
      let(:docx) do
        Caracal::Document.new do
          header(first: true) { p 'first header' }
          footer(first: true).p 'first footer'
          header.p 'header'
        end
      end

      it { expect(sect.at_xpath('w:titlePg', ns)).not_to be_nil }
      it { expect(referenced_texts docx, sect, 'header').to eq 'first' => ['first header'], 'default' => ['header'] }
      it { expect(referenced_texts docx, sect, 'footer').to eq 'first' => ['first footer'] }
    end

    it 'renders the same section and relationships twice' do
      docx = Caracal::Document.new { header.p 'h'; footer.p 'f'; page_numbers true, first_page: false }
      first, second = 2.times.map { parts(docx).values_at 'word/document.xml', 'word/_rels/document.xml.rels' }

      expect(second).to eq first
    end

    it 'returns the same first page header on every call' do
      docx = Caracal::Document.new
      expect(docx.header(first: true)).to equal docx.header(first: true)
    end
  end

  describe 'widths' do
    let(:docx) do
      Caracal::Document.new do |d|
        d.page_size width: 11906, height: 16838 # A4
        d.page_columns 2
        d.header do
          table [['wide']]
          hr width: 1026
        end
      end
    end
    let(:header) { xml(docx, 'word/header1.xml') }

    it { expect(header.at_xpath('//w:tblW/@w:w', ns).value).to eq '9026' }
    it { expect(header.xpath('//w:p[w:pPr/w:pBdr]/w:pPr/w:ind/@*', ns).map(&:value)).to eq %w(4000 4000) }
  end
end
