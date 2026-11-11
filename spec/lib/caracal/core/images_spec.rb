require 'spec_helper'
require 'zlib'
require 'tmpdir'

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


  describe 'intrinsic size' do
    # PNG header only; enough to read the size
    def png_of(w, h)
      "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [w, h, 8, 2, 0, 0, 0].pack('NNC5') + [0].pack('N')
    end

    let(:model) { subject.contents.last }
    let(:size)  { [model.image_width, model.image_height] }

    context 'without width and height' do
      before { subject.img 'image.png', data: png_of(400, 300) }

      it { expect(size).to eq [400, 300] }
      it { expect(model.formatted_width).to eq 400 * 12700 }
    end

    context 'with a width only' do
      before { subject.img 'image.png', data: png_of(400, 300), width: 200 }

      it { expect(size).to eq [200, 150] }
    end

    context 'with a height only' do
      before { subject.img 'image.png', data: png_of(400, 300), height: 100 }

      it { expect(size).to eq [133, 100] }
    end

    context 'with width and height' do
      before { subject.img 'image.png', data: png_of(400, 300), width: 10, height: 50 }

      it { expect(size).to eq [10, 50] }
    end

    context 'in a block' do
      before do
        img_data = png_of(400, 300)
        subject.img('image.png') { data img_data; width 40 }
      end

      it { expect(size).to eq [40, 30] }
    end

    context 'from a local file' do
      let(:path) { File.join Dir.mktmpdir, 'image.png' }

      before do
        File.binwrite path, png_of(5, 7)
        subject.img path
      end
      after { FileUtils.rm_rf File.dirname(path) }

      it { expect(size).to eq [5, 7] }
      it { expect(model.image_data).to eq png_of(5, 7) }
    end

    context 'from a remote url' do
      let(:url) { 'https://example.com/image.png' }

      before do
        allow(URI).to receive(:open) { |*_, &block| block.call StringIO.new(png_of(8, 9)) }
        subject.img url
      end

      it { expect(size).to eq [8, 9] }

      it 'downloads the image only once' do
        subject.render
        expect(URI).to have_received(:open).once
      end

      it 'embeds the downloaded data' do
        subject.render
        expect(subject.relationships_by_type(:image).first.relationship_data).to eq png_of(8, 9)
      end
    end

    context 'with an unsupported format' do
      it { expect { subject.img 'image.bmp', data: 'BM....' }.to raise_error(Caracal::Errors::InvalidModelError, /could not determine the size of image\.bmp/) }
      it { expect { subject.img 'image.bmp', data: 'BM....', width: 10 }.to raise_error(Caracal::Errors::InvalidModelError, /could not determine/) }
      it { expect { subject.img 'image.bmp', data: 'BM....', width: 10, height: 10 }.not_to raise_error }
    end

    context 'with an unreadable file' do
      it { expect { subject.img '/nonexistent/image.png' }.to raise_error(Caracal::Errors::InvalidModelError, /could not read \/nonexistent\/image\.png/) }
    end
  end


  describe 'media parts' do
    let(:entries) do
      zip = Zip::File.open_buffer StringIO.new(subject.render.string)
      zip.entries.to_h { |e| [e.name, e.get_input_stream.read] }
    end
    let(:media) { entries.keys.grep(%r{\Aword/media/}) }

    # media part of the first image relationship of a part
    def media_of(rels_name)
      rel = Nokogiri::XML(entries.fetch(rels_name)).remove_namespaces!.xpath('//Relationship').find { |r| r['Type'].end_with? '/image' }
      entries.fetch "word/#{rel['Target']}"
    end

    context 'with different images in body, header and footer' do
      before do
        subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0)
        subject.header.img 'image.png', width: 10, height: 10, data: png(0, 255, 0)
        subject.footer.img 'image.png', width: 10, height: 10, data: png(0, 0, 255)
      end

      it { expect(media.size).to eq 3 }
      it { expect(media_of 'word/_rels/document.xml.rels').to eq png(255, 0, 0) }
      it { expect(media_of 'word/_rels/header1.xml.rels').to eq png(0, 255, 0) }
      it { expect(media_of 'word/_rels/footer1.xml.rels').to eq png(0, 0, 255) }
    end

    context 'with the same image in body and header' do
      before do
        subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0)
        subject.header.img 'image.png', width: 10, height: 10, data: png(255, 0, 0)
      end

      it { expect(media.size).to eq 1 }
      it { expect(media_of 'word/_rels/header1.xml.rels').to eq png(255, 0, 0) }
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

    context 'with zero margins' do
      before { subject.img 'image.png', width: 10, height: 10, top: 0, bottom: 0, left: 0, right: 0 }

      let(:inline) { xml.at_xpath('//wp:inline', 'wp' => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing') }

      it { expect(%w(distT distB distL distR).map { |a| inline[a] }).to eq %w(0 0 0 0) }
    end

    context 'with anchored images' do
      before { 2.times { subject.img 'image.png', width: 10, height: 10, anchor: true } }

      let(:heights) { xml.xpath('//wp:anchor', 'wp' => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing').map { |n| n['relativeHeight'] } }

      it { expect(heights).to eq %w(1 2) }
    end

    context 'with anchored image positions' do
      let(:wp)     { { 'wp' => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing' } }
      let(:anchor) { xml.at_xpath('//wp:anchor', wp) }
      let(:pos_h)  { anchor.at_xpath('wp:positionH', wp) }
      let(:pos_v)  { anchor.at_xpath('wp:positionV', wp) }

      context 'by default' do
        before { subject.img 'image.png', width: 10, height: 10, align: :right, anchor: true }

        it { expect(pos_h['relativeFrom']).to eq 'page' }
        it { expect(pos_h.at_xpath('wp:align', wp).text).to eq 'right' }
        it { expect(pos_v['relativeFrom']).to eq 'page' }
        it { expect(pos_v.at_xpath('wp:align', wp).text).to eq 'top' }
        it { expect(anchor.at_xpath('wp:wrapTopAndBottom', wp)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'false' }
      end

      context 'with offsets' do
        before do
          subject.img 'image.png', width: 10, height: 10, anchor: true do
            x           1440
            y           720
            relative_to :margin
            wrap        :square
          end
        end

        it { expect(pos_h['relativeFrom']).to eq 'margin' }
        it { expect(pos_h.at_xpath('wp:posOffset', wp).text).to eq '914400' }
        it { expect(pos_v['relativeFrom']).to eq 'margin' }
        it { expect(pos_v.at_xpath('wp:posOffset', wp).text).to eq '457200' }
        it { expect(anchor.at_xpath('wp:wrapSquare', wp)['wrapText']).to eq 'bothSides' }
        it { expect(anchor.element_children.map(&:name)).to eq %w(simplePos positionH positionV extent effectExtent wrapSquare docPr cNvGraphicFramePr graphic) }
      end

      context 'with only a vertical offset' do
        before { subject.img 'image.png', width: 10, height: 10, align: :center, anchor: true, y: -100 }

        it { expect(pos_h.at_xpath('wp:align', wp).text).to eq 'center' }
        it { expect(pos_v.at_xpath('wp:posOffset', wp).text).to eq '-63500' }
      end

      {
        page:      %w(page page),
        margin:    %w(margin margin),
        column:    %w(column margin),
        paragraph: %w(column paragraph)
      }.each do |relative_to, (h, v)|
        context "relative to #{relative_to}" do
          before { subject.img 'image.png', width: 10, height: 10, anchor: true, x: 0, y: 0, relative_to: relative_to }

          it { expect([pos_h['relativeFrom'], pos_v['relativeFrom']]).to eq [h, v] }
        end
      end

      context 'with separate references per axis' do
        before { subject.img 'image.png', width: 10, height: 10, anchor: true, relative_to: :page, relative_to_y: :paragraph }

        it { expect([pos_h['relativeFrom'], pos_v['relativeFrom']]).to eq %w(page paragraph) }
      end

      context 'in front of text' do
        before { subject.img 'image.png', width: 10, height: 10, anchor: true, wrap: :none }

        it { expect(anchor.at_xpath('wp:wrapNone', wp)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'false' }
      end

      context 'behind text' do
        before { subject.img 'image.png', width: 10, height: 10, anchor: true, wrap: :behind }

        it { expect(anchor.at_xpath('wp:wrapNone', wp)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'true' }
      end
    end

    context 'with invalid anchor options' do
      it { expect { subject.img 'image.png', width: 10, height: 10, anchor: true, wrap: :tight }.to raise_error(Caracal::Errors::InvalidModelError, /:tight/) }
      it { expect { subject.img 'image.png', width: 10, height: 10, anchor: true, relative_to: :line }.to raise_error(Caracal::Errors::InvalidModelError, /:line/) }
      it { expect { subject.img 'image.png', width: 10, height: 10, anchor: true, relative_to_x: :foo }.to raise_error(Caracal::Errors::InvalidModelError) }
    end

    context 'with repeated, anchored and embedded drawings' do
      let(:drawing_ns) do
        {
          'wp'  => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
          'pic' => 'http://schemas.openxmlformats.org/drawingml/2006/picture'
        }
      end
      let(:doc_pr_ids)  { xml.xpath('//wp:docPr', drawing_ns).map { |n| n['id'] } }
      let(:c_nv_pr_ids) { xml.xpath('//pic:cNvPr', drawing_ns).map { |n| n['id'] } }

      before do
        2.times { subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0) }
        subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0), anchor: true
        subject.iframe data: File.binread(File.join(Caracal.root, 'spec', 'support', '_fixtures', 'snippet.docx'))
        subject.img 'image.png', width: 10, height: 10, data: png(255, 0, 0)
      end

      it { expect(doc_pr_ids.size).to eq 6 }
      it { expect(doc_pr_ids.uniq).to eq doc_pr_ids }
      it { expect(c_nv_pr_ids.uniq).to eq c_nv_pr_ids }
    end
  end

end
