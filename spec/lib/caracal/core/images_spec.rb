require 'spec_helper'
require 'zlib'

describe Caracal::Core::Images do
  subject { Caracal::Document.new }

  # 1x1 PNG of the given colour
  def png(r, g, b)
    chunk = ->(type, data) { [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N') }
    "\x89PNG\r\n\x1a\n".b +
      chunk['IHDR', [1, 1, 8, 2, 0, 0, 0].pack('NNC5')] +
      chunk['IDAT', Zlib::Deflate.deflate("\0".b + [r, g, b].pack('C3'))] +
      chunk['IEND', '']
  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    # .img
    describe '.img' do
      let!(:size) { subject.contents.size }

      before { subject.img 'https://www.google.com/images/srpr/logo11w.png', width: 538, height: 190, data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z/D/PwAHAwL/qGeMxAAAAABJRU5ErkJggg==" }

      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ImageModel) }
      it { expect(subject.contents.last.image_data).to be_truthy}
    end

  end


  #-------------------------------------------------------------
  # Rendering
  #-------------------------------------------------------------

  describe 'rendering' do
    let(:ns)     { { 'a' => 'http://schemas.openxmlformats.org/drawingml/2006/main' } }
    let(:xml)    { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(subject) }
    let(:embeds) { xml.xpath('//a:blip', ns).map { |n| n['r:embed'] } }
    let(:images) { xml and subject.relationships_by_type(:image) }
    let(:links)  { xml and subject.relationships_by_type(:link) }

    context 'with the same placeholder url and different data' do
      before do
        subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0)
        subject.img 'image.png', width: 10, height: 10, data: png(0, 0, 255)
      end

      it { expect(embeds.uniq.size).to eq 2 }
      it { expect(images.map(&:formatted_target).uniq.size).to eq 2 }
      it { expect(images.map(&:relationship_data)).to eq [png(255, 0, 0), png(0, 0, 255)] }
    end

    context 'with the same placeholder url and identical data' do
      before do
        2.times { subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0) }
      end

      it { expect(embeds.uniq.size).to eq 1 }
      it { expect(images.size).to eq 1 }
    end

    context 'with the same url and no data' do
      before do
        subject.img 'https://example.com/image.png', width: 10, height: 10
        subject.img 'https://example.com/IMAGE.png', width: 10, height: 10
      end

      it { expect(embeds.uniq.size).to eq 1 }
      it { expect(images.size).to eq 1 }
    end

    context 'with a link to the image url' do
      before do
        subject.p { link 'logo', 'https://example.com/image.png' }
        subject.img 'https://example.com/image.png', width: 10, height: 10
      end

      it { expect(images.size).to eq 1 }
      it { expect(links.size).to eq 1 }
    end
  end

end
