require 'spec_helper'
require 'stringio'
require 'tmpdir'

describe 'font embedding' do
  let(:ns) { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main', 'r' => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships' } }

  # minimal TrueType font: sfnt header, one table record, an OS/2 table carrying fsType
  def sfnt(fs_type: 0, version: 0x00010000)
    os2    = [0, 0, 400, 5, fs_type].pack('n5') + "\0".b * 16
    header = [version, 1, 16, 0, 0].pack('Nn4')
    record = ['OS/2', 0, 28, os2.bytesize].pack('a4N3')
    (header + record + os2).b
  end

  let(:regular) { sfnt }
  let(:bold)    { sfnt fs_type: 8 }

  let(:document) do
    regular_io, bold_io = StringIO.new(regular), StringIO.new(bold)
    Caracal::Document.new do |docx|
      docx.font name: 'Embedded Serif', regular: regular_io, bold: bold_io
      docx.p 'text', font: 'Embedded Serif'
    end
  end

  # renders the document and returns its parts by name
  def parts(document)
    zip = Zip::File.open_buffer document.render.string
    zip.entries.to_h {|entry| [entry.name, entry.get_input_stream.read] }
  end

  let(:package)    { parts document }
  let(:font_table) { Nokogiri::XML package['word/fontTable.xml'] }
  let(:font)       { font_table.at_xpath("//w:font[@w:name='Embedded Serif']", ns) }
  let(:rels)       { Nokogiri::XML(package['word/_rels/fontTable.xml.rels']).remove_namespaces! }

  describe 'FontModel' do
    let(:model) { document.find_font 'Embedded Serif' }

    it { expect(model.embedded?).to be true }
    it { expect(model.font_obfuscate).to be true }
    it { expect(model.embedded_fonts.map(&:style)).to eq %i(regular bold) }
    it { expect(model.embedded_fonts.map(&:key)).to all match(/\A\{\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\}\z/) }
    it { expect(document.find_font('Arial').embedded?).to be false }

    it 'reads font files from a path' do
      Dir.mktmpdir do |dir|
        path = File.join dir, 'font.ttf'
        File.binwrite path, regular
        expect(Caracal::Core::Models::FontModel.new(name: 'X', regular: path).embedded_fonts.first.font_file.data).to eq regular
      end
    end

    it { expect { Caracal::Core::Models::FontModel.new name: 'X', regular: '/does/not/exist.ttf' }.to raise_error(Caracal::Errors::InvalidFontError, /cannot read/) }
    it { expect { Caracal::Core::Models::FontModel.new name: 'X', regular: StringIO.new(sfnt(fs_type: 2)) }.to raise_error(Caracal::Errors::InvalidFontError) }
    it { expect { Caracal::Core::Models::FontModel.new name: 'X', regular: StringIO.new(sfnt(version: 0x4F54544F)) }.to raise_error(Caracal::Errors::InvalidFontError) }

    it 'supports the block syntax' do
      io = StringIO.new regular
      model = Caracal::Core::Models::FontModel.new do
        name 'X'
        italic io
        obfuscate false
      end
      expect(model.embedded_fonts.map(&:style)).to eq %i(italic)
      expect(model.font_obfuscate).to be false
    end
  end

  describe 'obfuscated (default)' do
    it { expect(font.xpath('w:embedRegular|w:embedBold', ns).map(&:name)).to eq %w(embedRegular embedBold) }
    it { expect(font.xpath('*/@r:id', ns).map(&:value)).to eq %w(rId1 rId2) }
    it { expect(font.xpath('*/@w:fontKey', ns).map(&:value)).to eq document.find_font('Embedded Serif').embedded_fonts.map(&:key) }
    it { expect(font_table.at_xpath("//w:font[@w:name='Arial']", ns).children).to be_empty }

    it { expect(rels.xpath('//Relationship').map {|r| [r['Id'], r['Target'], r['Type']] }).to eq [
      ['rId1', 'fonts/font1.odttf', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font'],
      ['rId2', 'fonts/font2.odttf', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/font'],
    ] }

    it 'stores the obfuscated font files' do
      keys = document.find_font('Embedded Serif').embedded_fonts.map(&:key)
      expect(Caracal::FontFile.deobfuscate package['word/fonts/font1.odttf'], keys[0]).to eq regular
      expect(Caracal::FontFile.deobfuscate package['word/fonts/font2.odttf'], keys[1]).to eq bold
      expect(package['word/fonts/font1.odttf']).not_to eq regular
    end

    it { expect(package['[Content_Types].xml']).to include 'Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"' }

    it 'sets embedTrueTypeFonts right after displayBackgroundShape' do
      settings = Nokogiri::XML package['word/settings.xml']
      expect(settings.xpath('/w:settings/*', ns).map(&:name).first(3)).to eq %w(displayBackgroundShape embedTrueTypeFonts defaultTabStop)
    end

    it 'keeps the same files and keys when rendered again' do
      expect(parts(document)).to include('word/fonts/font1.odttf' => package['word/fonts/font1.odttf'])
    end
  end

  describe 'not obfuscated' do
    let(:document) do
      io = StringIO.new regular
      Caracal::Document.new {|docx| docx.font name: 'Embedded Serif', regular: io, obfuscate: false }
    end

    it { expect(font.at_xpath('w:embedRegular/@w:fontKey', ns).value).to eq '{00000000-0000-0000-0000-000000000000}' }
    it { expect(rels.at_xpath('//Relationship/@Target').value).to eq 'fonts/font1.ttf' }
    it { expect(package['word/fonts/font1.ttf']).to eq regular }
    it { expect(package['[Content_Types].xml']).to include 'Extension="ttf" ContentType="application/x-font-ttf"' }
  end

  describe 'obfuscated .odttf files' do
    # keys as LibreOffice writes them; Word uses a random GUID for every file
    let(:key)        { '{01014A78-CABC-4EF0-12AC-5CD89AEFDE01}' }
    let(:bold_key)   { '{02014A78-CABC-4EF0-12AC-5CD89AEFDE02}' }
    let(:odttf)      { Caracal::FontFile.obfuscate regular, key }
    let(:bold_odttf) { Caracal::FontFile.obfuscate bold, bold_key }

    def font_model(options={}, &block)
      Caracal::Core::Models::FontModel.new({ name: 'X' }.merge(options), &block)
    end

    def data(model)
      model.embedded_fonts.to_h {|embedded| [embedded.style, embedded.font_file.data] }
    end

    let(:document) do
      io = StringIO.new odttf
      Caracal::Document.new {|docx| docx.font name: 'Embedded Serif', regular: io, key: key }
    end

    it { expect(odttf).not_to eq regular }
    it { expect(document.find_font('Embedded Serif').embedded_fonts.first.font_file.data).to eq regular }

    it 'embeds the de-obfuscated font like the original TTF' do
      font_key = font.at_xpath('w:embedRegular/@w:fontKey', ns).value
      expect(font_key).not_to eq key
      expect(Caracal::FontFile.deobfuscate package['word/fonts/font1.odttf'], font_key).to eq regular
    end

    it 'reads an .odttf file from a path' do
      Dir.mktmpdir do |dir|
        path = File.join dir, 'font1.odttf'
        File.binwrite path, odttf
        expect(data(font_model(key: key, regular: path))).to eq(regular: regular)
      end
    end

    it 'accepts the key without braces and in lowercase' do
      expect(data(font_model(regular: StringIO.new(odttf), key: key.delete('{}')))).to eq(regular: regular)
      expect(data(font_model(regular: StringIO.new(odttf), key: key.downcase))).to eq(regular: regular)
    end

    it 'takes a key per style' do
      model = font_model regular: StringIO.new(odttf), bold: StringIO.new(bold_odttf), key: { regular: key, 'bold' => bold_key }
      expect(data(model)).to eq(regular: regular, bold: bold)
    end

    it 'reads styles without a key as plain font files' do
      model = font_model regular: StringIO.new(odttf), bold: StringIO.new(bold), key: { regular: key }
      expect(data(model)).to eq(regular: regular, bold: bold)
    end

    it 'supports the block syntax with the key after the files' do
      regular_io, bold_io = StringIO.new(odttf), StringIO.new(bold_odttf)
      model = Caracal::Core::Models::FontModel.new do
        name    'X'
        regular regular_io
        bold    bold_io
        key     regular: '{01014A78-CABC-4EF0-12AC-5CD89AEFDE01}', bold: '{02014A78-CABC-4EF0-12AC-5CD89AEFDE02}'
      end
      expect(data(model)).to eq(regular: regular, bold: bold)
    end

    it 'embeds the plain font with obfuscate false' do
      io  = StringIO.new odttf
      doc = Caracal::Document.new {|docx| docx.font name: 'Embedded Serif', regular: io, key: key, obfuscate: false }
      expect(parts(doc)['word/fonts/font1.ttf']).to eq regular
    end

    describe 'with a wrong key' do
      it { expect { font_model regular: StringIO.new(odttf), key: '{001B70DC-AA60-4AD5-90EC-18A0948E1EAE}' }.to raise_error(Caracal::Errors::InvalidFontError, /regular font file does not de-obfuscate with key \{001B70DC-AA60-4AD5-90EC-18A0948E1EAE\}: not a TrueType\/OpenType font/) }
      it { expect { font_model regular: StringIO.new(odttf), bold: StringIO.new(bold_odttf), key: { regular: bold_key, bold: key } }.to raise_error(Caracal::Errors::InvalidFontError) }
      it { expect { font_model regular: StringIO.new(odttf), bold: StringIO.new(bold_odttf), key: key }.to raise_error(Caracal::Errors::InvalidFontError, /bold font file/) }
      it { expect { font_model regular: StringIO.new(odttf) }.to raise_error(Caracal::Errors::InvalidFontError, /not a TrueType\/OpenType font/) }
      it { expect { font_model regular: StringIO.new(odttf), key: '01014A78-CABC' }.to raise_error(Caracal::Errors::InvalidFontError, /invalid font obfuscation key/) }
      it { expect { font_model regular: StringIO.new(odttf), key: { bolditalic: key } }.to raise_error(Caracal::Errors::InvalidModelError, /unknown style bolditalic/) }
    end

    it 'checks the license of the de-obfuscated font' do
      restricted = Caracal::FontFile.obfuscate sfnt(fs_type: 2), key
      expect { font_model regular: StringIO.new(restricted), key: key }.to raise_error(Caracal::Errors::InvalidFontError, /license/)
    end
  end

  describe 'several embedded fonts' do
    let(:document) do
      a, b = StringIO.new(regular), StringIO.new(bold)
      Caracal::Document.new do |docx|
        docx.font name: 'A', bold: a
        docx.font name: 'B', regular: b
      end
    end

    it { expect(rels.xpath('//Relationship/@Id').map(&:value)).to eq %w(rId1 rId2) }
    it { expect(font_table.at_xpath("//w:font[@w:name='A']/w:embedBold/@r:id", ns).value).to eq 'rId1' }
    it { expect(font_table.at_xpath("//w:font[@w:name='B']/w:embedRegular/@r:id", ns).value).to eq 'rId2' }
    it { expect(package.keys).to include('word/fonts/font1.odttf', 'word/fonts/font2.odttf') }
  end

  describe 'without embedded fonts' do
    let(:document) { Caracal::Document.new {|docx| docx.p 'text' } }

    it { expect(package.keys.grep(/fonts\/|fontTable\.xml\.rels/)).to be_empty }
    it { expect(Nokogiri::XML(package['word/settings.xml']).xpath('//w:embedTrueTypeFonts', ns)).to be_empty }
  end
end
