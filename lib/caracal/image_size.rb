module Caracal

  # Reads the pixel size and density of PNG, JPEG and GIF data.
  #
  module ImageSize
    PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b
    # SOF markers C0-CF except DHT (C4), JPG (C8) and DAC (CC)
    JPEG_SOF      = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]
    JPEG_SOS      = 0xDA

    # Returns [width, height] or nil when the format is unknown.
    def self.read(data)
      data = data.to_s.b
      size = if png? data and data[12, 4] == 'IHDR'
        data[16, 8].to_s.unpack 'NN'
      elsif data.start_with? 'GIF87a' or data.start_with? 'GIF89a'
        data[6, 4].to_s.unpack 'vv'
      elsif jpeg? data
        jpeg_segments(data) { |marker, pos| break data[pos + 5, 4].to_s.unpack('nn').reverse if JPEG_SOF.include? marker }
      end
      size if size.is_a? Array and size.all? { |v| v.to_i > 0 }
    end

    # Returns the [x, y] dots per inch stored in the data, or nil when there
    # are none. PNG: pHYs chunk. JPEG: JFIF density, else EXIF resolution.
    def self.density(data)
      data = data.to_s.b
      dpi = if png? data
        png_density data
      elsif jpeg? data
        jpeg_density data
      end
      dpi if dpi and dpi.all? { |v| v > 0 }
    end

    def self.png?(data)
      data.start_with? PNG_SIGNATURE
    end

    def self.jpeg?(data)
      data.start_with? "\xFF\xD8".b
    end

    def self.png_density(data)
      pos = 8
      while pos + 8 <= data.bytesize
        length, type = data[pos, 8].unpack 'Na4'
        return if type == 'IDAT' or type == 'IEND'
        if type == 'pHYs' and length >= 9
          x, y, unit = data[pos + 8, 9].to_s.unpack 'NNC'
          return unless unit == 1 # pixels per metre; 0 is aspect ratio only
          return [x, y].map { |v| (v * 0.0254).round }
        end
        pos += 12 + length
      end
    end

    def self.jpeg_density(data)
      exif = nil
      jfif = jpeg_segments data do |marker, pos|
        break if JPEG_SOF.include? marker
        if marker == 0xE0 and data[pos + 4, 5] == "JFIF\x00".b
          unit, x, y = data[pos + 11, 5].to_s.unpack 'Cnn'
          break [x, y]                                   if unit == 1 # dots per inch
          break [x, y].map { |v| (v.to_i * 2.54).round } if unit == 2 # dots per cm
        elsif marker == 0xE1 and data[pos + 4, 6] == "Exif\x00\x00".b and exif.nil?
          length = data[pos + 2, 2].unpack1 'n'
          exif = exif_density data[pos + 10, length - 8].to_s
        end
      end
      jfif.is_a?(Array) ? jfif : exif
    end

    # XResolution, YResolution and ResolutionUnit from IFD0 of a TIFF block.
    def self.exif_density(tiff)
      short, long = {'II' => %w[v V], 'MM' => %w[n N]}[tiff[0, 2]]
      return unless short
      ifd   = tiff[4, 4].to_s.unpack1 long or return
      count = tiff[ifd, 2].to_s.unpack1 short or return
      tags  = {}
      count.times do |i|
        entry = tiff[ifd + 2 + i * 12, 12].to_s
        break if entry.bytesize < 12
        tag, type = entry.unpack short * 2
        if type == 3      # SHORT
          tags[tag] = entry[8, 2].unpack1 short
        elsif type == 5   # RATIONAL, stored at an offset
          num, den = tiff[entry[8, 4].unpack1(long), 8].to_s.unpack long * 2
          tags[tag] = num.to_f / den if num and den.to_i > 0
        end
      end
      x, y   = tags[0x011A], tags[0x011B]
      factor = {2 => 1, 3 => 2.54}[tags.fetch 0x0128, 2] # inch (default), cm
      [x, y].map { |v| (v * factor).round } if x and y and factor
    end

    # Yields marker and position of each JPEG segment before the scan data.
    def self.jpeg_segments(data)
      pos = 2
      while pos + 4 <= data.bytesize
        return unless data.getbyte(pos) == 0xFF
        marker = data.getbyte pos + 1
        if marker == 0xFF                                 # fill byte
          pos += 1
        elsif marker == 0x01 or (0xD0..0xD9).cover? marker  # no length
          pos += 2
        else
          return if marker == JPEG_SOS
          yield marker, pos
          pos += 2 + data[pos + 2, 2].unpack1('n')
        end
      end
    end

    private_class_method :png?, :jpeg?, :png_density, :jpeg_density, :exif_density, :jpeg_segments
  end

end
