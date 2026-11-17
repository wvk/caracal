require 'spec_helper'

describe Caracal::Core::CoreProperties do
  let(:ns) do
    {
      'cp'      => 'http://schemas.openxmlformats.org/package/2006/metadata/core-properties',
      'dc'      => 'http://purl.org/dc/elements/1.1/',
      'dcterms' => 'http://purl.org/dc/terms/',
      'xsi'     => 'http://www.w3.org/2001/XMLSchema-instance'
    }
  end

  subject { Caracal::Document.new 'report.docx' }

  let(:xml) { Nokogiri::XML Caracal::Renderers::CoreRenderer.render(subject) }

  def core_xml(bytes)
    zip = Zip::File.open_buffer bytes
    Nokogiri::XML zip.get_input_stream('docProps/core.xml').read
  end

  def rendered(element)
    node = xml.at_xpath "/cp:coreProperties/#{ element }", ns
    node and node.text
  end

  def w3cdtf_type(element)
    xml.at_xpath("/cp:coreProperties/#{ element }/@xsi:type", ns)&.value
  end

  describe 'text properties' do
    {
      title:            'dc:title',
      subject:          'dc:subject',
      creator:          'dc:creator',
      keywords:         'cp:keywords',
      description:      'dc:description',
      last_modified_by: 'cp:lastModifiedBy'
    }.each do |property, element|
      describe ".#{ property }" do
        before { subject.send property, 'Some value' }

        it { expect(subject.send property).to eq 'Some value' }
        it { expect(rendered element).to eq 'Some value' }
      end
    end
  end

  describe 'title' do
    describe 'when not set' do
      it { expect(subject.title).to be_nil }
      it { expect(rendered 'dc:title').to eq 'report.docx' }
    end

    describe 'when set' do
      before { subject.title 'Quarterly report' }

      it { expect(rendered 'dc:title').to eq 'Quarterly report' }
    end

    describe 'when the file name changes' do
      before { subject.file_name 'other.docx' }

      it { expect(rendered 'dc:title').to eq 'other.docx' }
    end

    describe 'when cleared' do
      before do
        subject.title 'Quarterly report'
        subject.title nil
      end

      it { expect(rendered 'dc:title').to eq 'report.docx' }
    end
  end

  describe 'keywords given as an array' do
    before { subject.keywords %w(sales 2024) }

    it { expect(rendered 'cp:keywords').to eq 'sales, 2024' }
  end

  describe 'text with control characters' do
    before { subject.subject "Sales\u0001 figures" }

    it { expect(rendered 'dc:subject').to eq 'Sales figures' }
  end

  describe 'date properties' do
    [[:created, 'dcterms:created'], [:modified, 'dcterms:modified']].each do |property, element|
      describe ".#{ property }" do
        before { subject.send property, value }

        describe 'given as Date' do
          let(:value) { Date.new(2024, 5, 17) }

          it { expect(subject.send property).to eq value }
          it { expect(rendered element).to eq '2024-05-17T00:00:00Z' }
          it { expect(w3cdtf_type element).to eq 'dcterms:W3CDTF' }
        end
        describe 'given as Time' do
          let(:value) { Time.new(2024, 5, 17, 14, 30, 0, '+02:00') }

          it { expect(rendered element).to eq '2024-05-17T12:30:00Z' }
        end
        describe 'given as DateTime' do
          let(:value) { DateTime.new(2024, 5, 17, 14, 30, 0, '+02:00') }

          it { expect(rendered element).to eq '2024-05-17T12:30:00Z' }
        end
        describe 'given as ISO 8601 String' do
          let(:value) { '2024-05-17T14:30:00+02:00' }

          it { expect(rendered element).to eq '2024-05-17T12:30:00Z' }
        end
      end

      describe "when #{ property } unparseable" do
        it { expect { subject.send property, 'someday' }.to raise_error(Caracal::Errors::InvalidModelError, /#{ property } must be a Date/) }
      end
    end
  end

  describe 'properties not set' do
    it { expect(xml.root.element_children.map(&:name)).to eq ['title'] }
  end

  describe 'all properties' do
    subject do
      Caracal::Document.new 'report.docx' do
        title            'Quarterly report'
        subject          'Sales figures'
        creator          'ACME Reporting'
        keywords         'sales, 2024'
        description      'Figures for the third quarter.'
        last_modified_by 'Jane Doe'
        created          Date.new(2024, 5, 17)
        modified         Date.new(2024, 6, 1)
      end
    end

    it 'are written in this order' do
      expect(xml.root.element_children.map {|n| "#{ n.namespace.prefix }:#{ n.name }" }).to eq \
        %w(dc:title dc:subject dc:creator cp:keywords dc:description cp:lastModifiedBy dcterms:created dcterms:modified)
    end

    it 'are written to docProps/core.xml' do
      expect(core_xml(subject.render.string).at_xpath('//dc:creator', ns).text).to eq 'ACME Reporting'
    end
  end

  describe 'writers' do
    before do
      subject.creator = 'ACME Reporting'
      subject.created = Date.new(2024, 5, 17)
    end

    it { expect(rendered 'dc:creator').to eq 'ACME Reporting' }
    it { expect(rendered 'dcterms:created').to eq '2024-05-17T00:00:00Z' }
    it { expect { subject.modified = 'someday' }.to raise_error(Caracal::Errors::InvalidModelError) }
  end

  describe 'through Caracal::View' do
    let(:export_class) do
      Class.new do
        include Caracal::View

        def initialize
          title   'Quarterly report'
          creator 'ACME Reporting'
        end
      end
    end

    subject { export_class.new.docx }

    it { expect(rendered 'dc:title').to eq 'Quarterly report' }
    it { expect(rendered 'dc:creator').to eq 'ACME Reporting' }
  end

  describe 'through a Tilt template' do
    let(:docx) { Tilt['report.docx.caracal'].new { "docx.title 'Quarterly report'" }.render }

    it { expect(core_xml(docx).at_xpath('//dc:title', ns).text).to eq 'Quarterly report' }
  end
end
