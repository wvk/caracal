module Caracal

  # Reads the pixel size of PNG, JPEG and GIF data.
  #
  module ImageSize
    PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b
    # SOF markers C0-CF except DHT (C4), JPG (C8) and DAC (CC)
    JPEG_SOF      = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]

    # Returns [width, height] or nil when the format is unknown.
    def self.read(data)
      data = data.to_s.b
      size = if data.start_with? PNG_SIGNATURE and data[12, 4] == 'IHDR'
        data[16, 8].to_s.unpack 'NN'
      elsif data.start_with? 'GIF87a' or data.start_with? 'GIF89a'
        data[6, 4].to_s.unpack 'vv'
      elsif data.start_with? "\xFF\xD8".b
        jpeg_size data
      end
      size if size and size.all? { |v| v.to_i > 0 }
    end

    def self.jpeg_size(data)
      pos = 2
      while pos + 4 <= data.bytesize
        return unless data.getbyte(pos) == 0xFF
        marker = data.getbyte pos + 1
        if marker == 0xFF                                 # fill byte
          pos += 1
        elsif marker == 0x01 or (0xD0..0xD9).cover? marker  # no length
          pos += 2
        else
          return data[pos + 5, 4].to_s.unpack('nn').reverse if JPEG_SOF.include? marker
          pos += 2 + data[pos + 2, 2].unpack1('n')
        end
      end
    end
    private_class_method :jpeg_size
  end

end
