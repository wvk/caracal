require 'spec_helper'

describe 'sections' do
  let(:ns)        { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:r)         { 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' }
  let(:landscape) { { width: 15840, height: 12240, orientation: :landscape } }

  # renders the document and returns its parts by name
  def parts(document)
    zip = Zip::File.open_buffer document.render.string
    zip.entries.to_h {|entry| [entry.name, entry.get_input_stream.read] }
  end

  def xml(document, name = 'word/document.xml', rendered = parts(document))
    Nokogiri::XML rendered.fetch(name)
  end

  def texts(node)
    node.xpath('.//w:t', ns).map(&:text)
  end

  def sect_prs(document)
    xml(document).xpath('//w:sectPr', ns)
  end

  # maps each section to its references: type => the texts of the referenced part
  def referenced_texts(document, kind)
    rendered = parts document
    rels     = Nokogiri::XML(rendered.fetch 'word/_rels/document.xml.rels').remove_namespaces!
    xml(document, 'word/document.xml', rendered).xpath('//w:sectPr', ns).map do |sect|
      sect.xpath("w:#{kind}Reference", ns).to_h do |ref|
        target = rels.at_xpath("//Relationship[@Id='#{ref.attribute_with_ns('id', r).value}']/@Target").value
        [ref['w:type'], texts(xml(document, "word/#{target}", rendered))]
      end
    end
  end

  describe 'portrait, landscape, portrait' do
    let(:docx) do
      Caracal::Document.new do |d|
        d.p 'portrait'
        d.section page_size: { width: 15840, height: 12240, orientation: :landscape }, page_margins: { top: 720, bottom: 720 } do
          d.table [%w(a b c)]
        end
        d.p 'portrait again'
      end
    end
    let(:sects) { sect_prs docx }
    let(:sizes) { sects.map {|sect| sect.at_xpath('w:pgSz', ns).attributes.transform_values(&:value) } }

    it { expect(sects.size).to eq 3 }
    it { expect(sizes.map {|size| size.values_at 'w', 'h', 'orient' }).to eq [%w(12240 15840 portrait), %w(15840 12240 landscape), %w(12240 15840 portrait)] }
    it { expect(sects.map {|sect| sect.at_xpath('w:pgMar/@w:top', ns).value }).to eq %w(1440 720 1440) }
    it { expect(sects.map {|sect| sect.at_xpath('w:pgMar/@w:left', ns).value }).to eq %w(1440 1440 1440) }

    it 'ends each section but the last in the properties of a paragraph' do
      expect(sects[0].parent.name).to eq 'pPr'
      expect(sects[1].parent.name).to eq 'pPr'
      expect(sects[2].parent.name).to eq 'body'
      expect(sects[2].next_element).to be_nil
    end

    it 'ends a section in its last paragraph' do
      expect(texts sects[0].parent.parent).to eq ['portrait']
      expect(xml(docx).xpath('//w:body/w:p', ns).size).to eq 3
    end

    it 'ends a section after a table in an empty paragraph, 1pt high' do
      closing = sects[1].parent.parent
      expect(closing.previous_element.name).to eq 'tbl'
      expect(texts closing).to be_empty
      expect(closing.at_xpath('w:pPr/w:spacing', ns).attributes.transform_values(&:value)).to include 'line' => '20', 'lineRule' => 'exact'
      expect(closing.at_xpath('w:pPr/w:rPr/w:sz/@w:val', ns).value).to eq '2'
    end

    it 'puts the section properties last in the paragraph properties' do
      expect(sects[0].previous_element.name).to eq 'rPr'
      expect(sects[0].next_element).to be_nil
    end

    it 'sizes the table to the landscape page' do
      expect(xml(docx).at_xpath('//w:tblW/@w:w', ns).value).to eq '12960'
    end
  end

  describe 'a document ending in a section' do
    let(:docx) do
      Caracal::Document.new do |d|
        d.p 'portrait'
        d.section(page_size: { width: 15840, height: 12240, orientation: :landscape }) { d.p 'landscape' }
      end
    end
    let(:sects) { sect_prs docx }

    it { expect(sects.size).to eq 2 }
    it { expect(sects.last.parent.name).to eq 'body' }
    it { expect(sects.last.at_xpath('w:pgSz/@w:orient', ns).value).to eq 'landscape' }
  end

  describe 'columns, page numbers and the first page' do
    let(:docx) do
      Caracal::Document.new do |d|
        d.page_columns 2
        d.page_numbers true, start: 5
        d.header(first: true) { p 'cover' }
        d.p 'two columns'
        d.section(columns: 1) { d.p 'one column' }
        d.section(columns: { count: 3, spacing: 200 }, different_first_page: true) { d.p 'three columns' }
        d.p 'two columns again'
      end
    end
    let(:sects) { sect_prs docx }

    it { expect(sects.map {|sect| sect.at_xpath('w:cols/@w:num', ns)&.value }).to eq ['2', nil, '3', '2'] }
    it { expect(sects[2].at_xpath('w:cols/@w:space', ns).value).to eq '200' }
    it { expect(sects.map {|sect| sect.at_xpath('w:pgNumType/@w:start', ns)&.value }).to eq ['5', nil, nil, nil] }
    it { expect(sects.map {|sect| !sect.at_xpath('w:titlePg', ns).nil? }).to eq [true, false, true, false] }
  end

  describe 'headers and footers' do
    it 'are inherited unless a section has its own' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.footer { p 'document footer' }
        d.p 'first'
        d.section(header: -> { p 'own header' }) { d.p 'second' }
        d.p 'third'
        d.section(footer: ->(f) { f.p 'own footer' }) { d.p 'fourth' }
      end

      expect(referenced_texts docx, 'header').to eq [{ 'default' => ['document header'] }, { 'default' => ['own header'] }, {}, {}]
      expect(referenced_texts docx, 'footer').to eq [{ 'default' => ['document footer'] }, {}, {}, { 'default' => ['own footer'] }]
    end

    it 'write a part of their own for each section' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.p 'first'
        d.section(header: d.header) { d.p 'second' }
        d.section(header: Caracal::Header.new(document: d) { p 'given header' }) { d.p 'third' }
      end
      rendered = parts docx

      expect(rendered.keys.grep(/word\/header/)).to eq %w(word/header1.xml word/header3.xml word/header4.xml)
      expect(texts xml(docx, 'word/header3.xml', rendered)).to eq ['document header']
      expect(texts xml(docx, 'word/header4.xml', rendered)).to eq ['given header']
      expect(referenced_texts docx, 'header').to eq [{ 'default' => ['document header'] }, { 'default' => ['document header'] }, { 'default' => ['given header'] }]
    end

    it 'start with the document header in a first section of its own' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.footer { p 'document footer' }
        d.section(header: -> { p 'own header' }) { d.p 'first' }
        d.p 'second'
      end

      expect(referenced_texts docx, 'header').to eq [{ 'default' => ['own header'] }, {}]
      expect(referenced_texts docx, 'footer').to eq [{ 'default' => ['document footer'] }, {}]
    end

    it 'take the page number below their content' do
      docx = Caracal::Document.new do |d|
        d.page_numbers true
        d.p 'first'
        d.section(footer: -> { p 'own footer' }) { d.p 'second' }
      end
      footer = xml docx, 'word/footer3.xml'

      expect(texts footer).to eq ['own footer']
      expect(footer.at_xpath('//w:p[2]//w:instrText', ns).text.strip).to eq 'PAGE'
    end

    it 'declare their parts and relationships' do
      docx = Caracal::Document.new do |d|
        d.p 'first'
        d.section(header: -> { p 'h' }, footer: -> { p 'f' }) { d.p 'second' }
      end
      rendered = parts docx
      types    = Nokogiri::XML(rendered.fetch '[Content_Types].xml').remove_namespaces!
      rels     = Nokogiri::XML(rendered.fetch 'word/_rels/document.xml.rels').remove_namespaces!

      expect(types.xpath('//Override/@PartName').map(&:value).grep(%r{/word/(header|footer)})).to eq %w(/word/header3.xml /word/footer3.xml)
      expect(rels.xpath("//Relationship[contains(@Type, '/header') or contains(@Type, '/footer')]/@Target").map(&:value)).to eq %w(header3.xml footer3.xml)
    end

    it 'fit a table to the section page' do
      docx = Caracal::Document.new do |d|
        d.p 'first'
        d.section(page_size: { width: 15840, height: 12240, orientation: :landscape }, header: -> { table [['wide']] }) { d.p 'second' }
      end
      expect(xml(docx, 'word/header3.xml').at_xpath('//w:tblW/@w:w', ns).value).to eq '12960'
    end

    it 'render the same sections and relationships twice' do
      docx = Caracal::Document.new do |d|
        d.header { p 'h' }
        d.page_numbers true, first_page: false
        d.p 'first'
        d.section(header: -> { p 'own' }, different_first_page: true) { d.p 'second' }
        d.p 'third'
      end
      first, second = 2.times.map { parts(docx).values_at 'word/document.xml', 'word/_rels/document.xml.rels' }

      expect(second).to eq first
    end
  end

  describe 'a different first page' do
    it 'shows the first-page header and footer of the section' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.p 'first'
        d.section(header: { default: -> { p 'chapter' }, first: -> { p 'chapter opening' } }) { d.p 'second' }
      end

      expect(referenced_texts(docx, 'header').last).to eq 'default' => ['chapter'], 'first' => ['chapter opening']
      expect(sect_prs(docx).last.at_xpath('w:titlePg', ns)).not_to be_nil
    end

    it 'shows the default header and footer without first-page ones, with the page number' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.page_numbers true
        d.p 'first'
        d.section(different_first_page: true) { d.p 'second' }
      end

      expect(referenced_texts(docx, 'header').last).to eq 'first' => ['document header']
      expect(referenced_texts(docx, 'footer').last.keys).to eq %w(first)
      expect(xml(docx, 'word/footer3.xml').xpath('//w:instrText', ns)).not_to be_empty
    end

    it 'leaves the page number off with first_page: false' do
      docx = Caracal::Document.new do |d|
        d.page_numbers true, first_page: false
        d.p 'first'
        d.section(different_first_page: true) { d.p 'second' }
      end

      expect(xml(docx, 'word/footer3.xml').xpath('//w:instrText', ns)).to be_empty
    end

    it 'writes a blank first-page header, which would show the previous one' do
      docx = Caracal::Document.new do |d|
        d.header { p 'document header' }
        d.p 'first'
        d.section(header: { default: -> { p 'chapter' }, first: -> {} }) { d.p 'second' }
      end

      expect(referenced_texts(docx, 'header').last).to eq 'default' => ['chapter'], 'first' => []
    end

    it 'shows the document first page in the first section' do
      docx = Caracal::Document.new do |d|
        d.header(first: true) { p 'cover' }
        d.section(page_size: { width: 15840, height: 12240, orientation: :landscape }) { d.p 'first' }
        d.p 'second'
      end

      expect(referenced_texts docx, 'header').to eq [{ 'first' => ['cover'] }, {}]
      expect(sect_prs(docx).map {|sect| !sect.at_xpath('w:titlePg', ns).nil? }).to eq [true, false]
    end
  end
end
