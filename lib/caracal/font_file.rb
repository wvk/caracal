require 'securerandom'
require 'caracal/errors'


module Caracal

  # This class wraps the bytes of a TrueType/OpenType font file. It knows
  # enough of the sfnt format to tell whether the font may be embedded in a
  # document, and implements the font obfuscation of ECMA-376 Part 1 §17.8.1.
  #
  class FontFile
    OBFUSCATED_LENGTH = 32
    ZERO_KEY          = '{00000000-0000-0000-0000-000000000000}'

    SFNT_TRUETYPE = ["\x00\x01\x00\x00".b, 'true'.b].freeze
    SFNT_CFF      = 'OTTO'.b
    HEADER_SIZE   = 12
    RECORD_SIZE   = 16
    GUID_PATTERN  = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    # fsType usage permission bits
    FS_RESTRICTED  = 0x0002
    FS_PREVIEW     = 0x0004
    FS_EDITABLE    = 0x0008
    FS_BITMAP_ONLY = 0x0200

    attr_reader :data


    #=============== CLASS METHODS ========================

    def self.generate_key
      "{#{ SecureRandom.uuid.upcase }}"
    end

    # XORs the first 32 bytes of data with the key. The operation is its own
    # inverse, so the same method deobfuscates.
    def self.obfuscate(data, key)
      key_bytes = key_bytes_for key
      result    = data.to_s.dup.b
      if result.bytesize < OBFUSCATED_LENGTH
        raise Errors::InvalidFontError, "font data is too short to obfuscate (#{ result.bytesize } bytes, need at least #{ OBFUSCATED_LENGTH })"
      end

      OBFUSCATED_LENGTH.times do |i|
        result.setbyte i, result.getbyte(i) ^ key_bytes[i % key_bytes.size]
      end
      result
    end

    def self.deobfuscate(data, key)
      obfuscate data, key
    end

    # The GUID's 16 bytes in reversed order, as prescribed by §17.8.1.
    def self.key_bytes_for(key)
      guid = key.to_s.strip
      guid = guid[1..-2] if guid.start_with?('{') and guid.end_with?('}')
      unless key.is_a?(String) and guid =~ GUID_PATTERN
        raise ArgumentError, "invalid font obfuscation key #{ key.inspect }, expected a GUID like #{ ZERO_KEY }"
      end

      [guid.delete('-')].pack('H*').bytes.reverse
    end
    private_class_method :key_bytes_for


    #=============== INITIALIZATION =======================

    def initialize(data)
      unless data.is_a? String
        raise Errors::InvalidFontError, "font data must be a String, got #{ data.class }"
      end

      @data = data.dup.b
      @tables = parse_table_directory
    end


    #=============== GETTERS ==============================

    def outline_format
      @data.byteslice(0, 4) == SFNT_CFF ? :cff : :truetype
    end

    def truetype?
      outline_format == :truetype
    end

    def fs_type
      return @fs_type if defined? @fs_type

      @fs_type = if (os2 = @tables['OS/2'])
        @data.byteslice(os2[:offset] + 8, 2).unpack1 'n'
      end
    end

    # Versions 0-2 of the OS/2 table allow several usage bits at once; the
    # least restrictive one applies.
    def embedding_permission
      usage = fs_type.to_i & 0x000F

      if usage & FS_EDITABLE != 0
        :editable
      elsif usage & FS_PREVIEW != 0
        :preview_and_print
      elsif usage & FS_RESTRICTED != 0
        :restricted
      else
        :installable
      end
    end

    def bitmap_only?
      fs_type.to_i & FS_BITMAP_ONLY != 0
    end


    #=============== VALIDATION ===========================

    def check_embeddable!
      unless truetype?
        raise Errors::InvalidFontError, 'font has CFF (PostScript) outlines; only fonts with TrueType outlines can be embedded'
      end
      if embedding_permission == :restricted
        raise Errors::InvalidFontError, 'font license does not permit embedding (fsType: Restricted License)'
      end
      if bitmap_only?
        raise Errors::InvalidFontError, 'font license only permits embedding bitmaps (fsType: Bitmap embedding only)'
      end
      if embedding_permission == :preview_and_print
        warn 'caracal: font license only permits Preview & Print embedding; Word will open the document read-only'
      end

      self
    end


    private

    # Returns { tag => { offset:, length: } } for every table record, after
    # checking the sfnt header and that the OS/2 table lies within the data.
    def parse_table_directory
      check_signature

      if @data.bytesize < HEADER_SIZE
        raise Errors::InvalidFontError, 'font data is truncated (incomplete sfnt header)'
      end
      num_tables = @data.byteslice(4, 2).unpack1 'n'
      if num_tables == 0
        raise Errors::InvalidFontError, 'font contains no tables'
      end
      if @data.bytesize < HEADER_SIZE + num_tables * RECORD_SIZE
        raise Errors::InvalidFontError, "font data is truncated (table directory declares #{ num_tables } tables)"
      end

      tables = {}
      num_tables.times do |i|
        tag, _checksum, offset, length = @data.byteslice(HEADER_SIZE + i * RECORD_SIZE, RECORD_SIZE).unpack 'a4NNN'
        tables[tag] = { offset: offset, length: length }
      end

      if (os2 = tables['OS/2'])
        if os2[:length] < 10 or os2[:offset] + 10 > @data.bytesize
          raise Errors::InvalidFontError, 'font data is corrupt (OS/2 table is truncated or lies outside the file)'
        end
      end

      tables
    end

    def check_signature
      signature = @data.byteslice(0, 4)

      case signature
      when *SFNT_TRUETYPE, SFNT_CFF
        nil
      when 'ttcf'.b
        raise Errors::InvalidFontError, 'font collections (.ttc/.otc) are not supported; extract a single font first'
      when 'wOFF'.b
        raise Errors::InvalidFontError, 'WOFF fonts are not supported; convert to a TrueType (.ttf) font first'
      when 'wOF2'.b
        raise Errors::InvalidFontError, 'WOFF2 fonts are not supported; convert to a TrueType (.ttf) font first'
      else
        raise Errors::InvalidFontError, 'not a TrueType/OpenType font'
      end
    end

  end
end
