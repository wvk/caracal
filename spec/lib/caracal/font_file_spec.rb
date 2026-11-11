require 'spec_helper'
require 'caracal/font_file'

describe Caracal::FontFile do
  # Assembles a minimal sfnt: header, table directory and the given tables.
  # Pass os2: false to omit the OS/2 table.
  def sfnt(version: "\x00\x01\x00\x00", fs_type: 0, os2: true)
    tables = { 'head' => "\x00".b * 54 }
    tables['OS/2'] = [3, 500, 400, 5, fs_type].pack('nnnnn') + "\x00".b * 86 if os2

    offset    = 12 + 16 * tables.size
    directory = ''.b
    body      = ''.b
    tables.each do |tag, bytes|
      directory << [tag, 0, offset + body.bytesize, bytes.bytesize].pack('a4NNN')
      body << bytes
    end

    version.b + [tables.size, 0, 0, 0].pack('nnnn') + directory + body
  end

  def font(**options)
    described_class.new sfnt(**options)
  end

  let(:ecma_key)       { '{001B70DC-AA60-4AD5-90EC-18A0948E1EAE}' }
  let(:ecma_key_bytes) { ['AE1E8E94A018EC90D54A60AADC701B00'].pack 'H*' }


  #-------------------------------------------------------------
  # Format detection
  #-------------------------------------------------------------

  describe 'format detection' do
    it 'accepts TrueType outlines with version 0x00010000' do
      expect(font.outline_format).to eq :truetype
      expect(font.truetype?).to eq true
    end

    it 'accepts TrueType outlines with version "true"' do
      expect(font(version: 'true').outline_format).to eq :truetype
    end

    it 'accepts CFF outlines' do
      f = font version: 'OTTO'
      expect(f.outline_format).to eq :cff
      expect(f.truetype?).to eq false
    end

    it 'stores a binary copy of the data' do
      bytes = sfnt.force_encoding 'UTF-8'
      f     = described_class.new bytes
      expect(f.data.encoding).to eq Encoding::ASCII_8BIT
      expect(f.data).not_to be bytes
      expect(bytes.encoding).to eq Encoding::UTF_8
    end

    {
      'ttcf' => /collection/i,
      'wOFF' => /WOFF fonts/,
      'wOF2' => /WOFF2/,
      'GIF8' => /not a TrueType\/OpenType font/,
    }.each do |signature, message|
      it "rejects data starting with #{ signature }" do
        expect { described_class.new sfnt(version: signature) }.to raise_error(Caracal::Errors::InvalidFontError, message)
      end
    end

    it 'rejects empty data' do
      expect { described_class.new '' }.to raise_error(Caracal::Errors::InvalidFontError, /not a TrueType/)
    end

    it 'rejects non-strings' do
      expect { described_class.new nil }.to raise_error(Caracal::Errors::InvalidFontError)
    end

    it 'rejects a truncated header' do
      expect { described_class.new sfnt[0, 8] }.to raise_error(Caracal::Errors::InvalidFontError, /truncated/)
    end

    it 'rejects a truncated table directory' do
      expect { described_class.new sfnt[0, 30] }.to raise_error(Caracal::Errors::InvalidFontError, /truncated/)
    end

    it 'rejects a font without tables' do
      expect { described_class.new "\x00\x01\x00\x00".b + "\x00".b * 8 }.to raise_error(Caracal::Errors::InvalidFontError)
    end

    it 'rejects an OS/2 table that lies outside the data' do
      bytes = sfnt
      expect { described_class.new bytes[0, bytes.bytesize - 90] }.to raise_error(Caracal::Errors::InvalidFontError, /OS\/2/)
    end

    it 'never raises anything but InvalidFontError on truncated data' do
      bytes = sfnt
      (0...bytes.bytesize).each do |length|
        begin
          described_class.new(bytes[0, length]).fs_type
        rescue Caracal::Errors::InvalidFontError
        end
      end
    end
  end


  #-------------------------------------------------------------
  # Embedding permissions
  #-------------------------------------------------------------

  describe 'embedding permissions' do
    it 'reads fsType from the OS/2 table' do
      expect(font(fs_type: 0x0304).fs_type).to eq 0x0304
    end

    it 'treats a font without OS/2 table as installable' do
      f = font os2: false
      expect(f.fs_type).to be_nil
      expect(f.embedding_permission).to eq :installable
      expect(f.bitmap_only?).to eq false
    end

    {
      0x0000 => :installable,
      0x0002 => :restricted,
      0x0004 => :preview_and_print,
      0x0008 => :editable,
      0x0006 => :preview_and_print,
      0x000A => :editable,
      0x000C => :editable,
      0x000E => :editable,
      0x0100 => :installable,
      0x0108 => :editable,
    }.each do |value, permission|
      it "maps fsType 0x#{ '%04X' % value } to #{ permission }" do
        expect(font(fs_type: value).embedding_permission).to eq permission
      end
    end

    it 'detects bitmap-only embedding' do
      expect(font(fs_type: 0x0200).bitmap_only?).to eq true
      expect(font(fs_type: 0x0100).bitmap_only?).to eq false
    end
  end


  #-------------------------------------------------------------
  # check_embeddable!
  #-------------------------------------------------------------

  describe '#check_embeddable!' do
    it 'returns self for installable TrueType fonts' do
      f = font
      expect(f.check_embeddable!).to be f
    end

    it 'returns self for editable fonts' do
      expect { font(fs_type: 0x0008).check_embeddable! }.not_to output.to_stderr
    end

    it 'returns self for fonts without OS/2 table' do
      expect { font(os2: false).check_embeddable! }.not_to raise_error
    end

    it 'raises for CFF outlines' do
      expect { font(version: 'OTTO').check_embeddable! }.to raise_error(Caracal::Errors::InvalidFontError, /CFF/)
    end

    it 'raises for restricted fonts' do
      expect { font(fs_type: 0x0002).check_embeddable! }.to raise_error(Caracal::Errors::InvalidFontError, /Restricted/)
    end

    it 'raises for bitmap-only fonts' do
      expect { font(fs_type: 0x0200).check_embeddable! }.to raise_error(Caracal::Errors::InvalidFontError, /bitmap/i)
    end

    it 'warns for preview & print fonts' do
      f = font fs_type: 0x0004
      expect { expect(f.check_embeddable!).to be f }.to output(/read-only/).to_stderr
    end
  end


  #-------------------------------------------------------------
  # Obfuscation
  #-------------------------------------------------------------

  describe '.obfuscate' do
    let(:data) { (0...40).map { |i| i * 7 % 256 }.pack 'C*' }

    it 'XORs both 16 byte halves with the reversed GUID bytes (ECMA-376 example)' do
      result = described_class.obfuscate "\x00".b * 32, ecma_key
      expect(result).to eq ecma_key_bytes * 2
    end

    it 'XORs arbitrary bytes with the reversed GUID bytes' do
      result = described_class.obfuscate "\xFF".b * 32, ecma_key
      expect(result.unpack1 'H*').to eq '51e1716b5fe7136f2ab59f55238fe4ff' * 2
    end

    it 'is its own inverse' do
      once = described_class.obfuscate data, ecma_key
      expect(once).not_to eq data
      expect(described_class.obfuscate once, ecma_key).to eq data
      expect(described_class.deobfuscate once, ecma_key).to eq data
    end

    it 'leaves bytes beyond the first 32 untouched' do
      result = described_class.obfuscate data, ecma_key
      expect(result.bytesize).to eq data.bytesize
      expect(result[32..]).to eq data[32..]
    end

    it 'does not mutate its argument' do
      original = data.dup
      described_class.obfuscate data, ecma_key
      expect(data).to eq original
    end

    it 'returns a binary string' do
      result = described_class.obfuscate data.dup.force_encoding('UTF-8'), ecma_key
      expect(result.encoding).to eq Encoding::ASCII_8BIT
    end

    it 'accepts keys without braces and in lower case' do
      expected = described_class.obfuscate data, ecma_key
      expect(described_class.obfuscate data, ecma_key.delete('{}')).to eq expected
      expect(described_class.obfuscate data, ecma_key.downcase).to eq expected
    end

    it 'leaves data unchanged with the zero key' do
      expect(described_class.obfuscate data, described_class::ZERO_KEY).to eq data
    end

    ['', 'not-a-guid', '{001B70DC-AA60-4AD5-90EC-18A0948E1EA}', '{001B70DC-AA60-4AD5-90EC-18A0948E1EAG}',
     '001B70DCAA604AD590EC18A0948E1EAE0', '{001B70DC-AA60-4AD5-90EC-18A0948E1EAE', nil].each do |key|
      it "raises ArgumentError for key #{ key.inspect }" do
        expect { described_class.obfuscate data, key }.to raise_error(ArgumentError)
      end
    end

    it 'raises InvalidFontError for data shorter than 32 bytes' do
      expect { described_class.obfuscate data[0, 31], ecma_key }.to raise_error(Caracal::Errors::InvalidFontError)
    end
  end

  describe '.generate_key' do
    it 'returns an upper case GUID in braces' do
      expect(described_class.generate_key).to match /\A\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}\z/
      expect(described_class.generate_key).not_to match /[a-f]/
    end

    it 'returns a different key each time' do
      keys = Array.new(20) { described_class.generate_key }
      expect(keys.uniq.size).to eq 20
    end

    it 'is usable as obfuscation key' do
      expect { described_class.obfuscate "\x00".b * 32, described_class.generate_key }.not_to raise_error
    end
  end
end
