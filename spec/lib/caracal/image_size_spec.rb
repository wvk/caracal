require 'spec_helper'

describe Caracal::ImageSize do
  def png(w, h, *chunks)
    "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [w, h, 8, 2, 0, 0, 0].pack('NNC5') + [0].pack('N') + chunks.join
  end

  def chunk(type, data)
    [data.bytesize].pack('N') + type + data + [0].pack('N')
  end

  def phys(x, y, unit)
    chunk 'pHYs', [x, y, unit].pack('NNC')
  end

  def jfif(unit, x, y)
    "\xFF\xE0".b + [16].pack('n') + "JFIF\x00\x01\x01".b + [unit, x, y, 0, 0].pack('CnnCC')
  end

  # APP1 with an IFD0 holding XResolution, YResolution and ResolutionUnit
  def exif(x, y, unit, order: 'II')
    s, l = order == 'II' ? %w[v V] : %w[n N]
    entry = ->(tag, type, value) { [tag, type].pack(s * 2) + [1].pack(l) + value }
    tiff = order.b + [42].pack(s) + [8].pack(l) + [3].pack(s) +
      entry[0x011A, 5, [50].pack(l)] +
      entry[0x011B, 5, [58].pack(l)] +
      entry[0x0128, 3, [unit].pack(s) + "\x00\x00".b] +
      [0].pack(l) + [x, 1, y, 1].pack(l * 4)
    "\xFF\xE1".b + [8 + tiff.bytesize].pack('n') + "Exif\x00\x00".b + tiff
  end

  def jpeg_with(*segments)
    "\xFF\xD8".b + segments.join + "\xFF\xC0".b + [11, 8, 1, 1, 1].pack('nCnnC') + "\x01\x11\x00".b + "\xFF\xD9".b
  end

  def gif(version, w, h)
    version.b + [w, h].pack('vv') + "\x00\x00\x00".b
  end

  # SOI, APP0, DHT (C4 is not a frame marker), fill byte, SOFn
  def jpeg(sof, w, h)
    "\xFF\xD8".b +
      "\xFF\xE0".b + [16].pack('n') + "JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00".b +
      "\xFF\xC4".b + [5].pack('n') + "\x00\x00\x00".b +
      "\xFF\xFF".b + sof.chr.b + [11, 8, h, w, 1].pack('nCnnC') + "\x01\x11\x00".b +
      "\xFF\xD9".b
  end

  it { expect(described_class.read png(640, 480)).to eq [640, 480] }
  it { expect(described_class.read gif('GIF87a', 300, 2)).to eq [300, 2] }
  it { expect(described_class.read gif('GIF89a', 1, 4464)).to eq [1, 4464] }
  it { expect(described_class.read jpeg(0xC0, 1024, 768)).to eq [1024, 768] }
  it { expect(described_class.read jpeg(0xC2, 33, 44)).to eq [33, 44] }  # progressive
  it { expect(described_class.read 'not an image').to be_nil }
  it { expect(described_class.read nil).to be_nil }
  it { expect(described_class.read png(640, 480)[0, 18]).to be_nil }     # truncated
  it { expect(described_class.read "\xFF\xD8\xFF\xE0".b).to be_nil }

  describe '.density' do
    it { expect(described_class.density png(1, 1, phys(3780, 3780, 1))).to eq [96, 96] }
    it { expect(described_class.density png(1, 1, chunk('gAMA', 'xxxx'), phys(11811, 5906, 1))).to eq [300, 150] }
    it { expect(described_class.density png(1, 1, phys(1, 1, 0))).to be_nil }         # aspect ratio only
    it { expect(described_class.density png(1, 1, chunk('IDAT', ''), phys(3780, 3780, 1))).to be_nil }
    it { expect(described_class.density png(1, 1)).to be_nil }
    it { expect(described_class.density jpeg_with(jfif(1, 300, 200))).to eq [300, 200] }
    it { expect(described_class.density jpeg_with(jfif(2, 118, 59))).to eq [300, 150] }
    it { expect(described_class.density jpeg_with(jfif(0, 1, 1))).to be_nil }
    it { expect(described_class.density jpeg_with(exif(300, 200, 2))).to eq [300, 200] }
    it { expect(described_class.density jpeg_with(exif(300, 200, 2, order: 'MM'))).to eq [300, 200] }
    it { expect(described_class.density jpeg_with(exif(118, 118, 3))).to eq [300, 300] }
    it { expect(described_class.density jpeg_with(exif(300, 300, 1))).to be_nil }     # no unit
    it { expect(described_class.density jpeg_with(jfif(0, 1, 1), exif(150, 150, 2))).to eq [150, 150] }
    it { expect(described_class.density jpeg_with(jfif(1, 300, 300), exif(150, 150, 2))).to eq [300, 300] }
    it { expect(described_class.density jpeg(0xC0, 1, 1)).to be_nil }
    it { expect(described_class.density gif('GIF89a', 1, 1)).to be_nil }
    it { expect(described_class.density jpeg_with(exif(300, 300, 2))[0, 30]).to be_nil } # truncated
    it { expect(described_class.density nil).to be_nil }
  end
end
