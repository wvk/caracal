require 'spec_helper'

describe Caracal::ImageSize do
  def png(w, h)
    "\x89PNG\r\n\x1a\n".b + [13].pack('N') + 'IHDR' + [w, h, 8, 2, 0, 0, 0].pack('NNC5') + [0].pack('N')
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
end
