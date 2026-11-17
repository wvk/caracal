require 'fileutils'

# With OOXML_DUMP_DIR set, every document the specs render is also written
# to that directory, for `rake ooxml` to validate with the Open XML SDK.
# Each file is named after the example that rendered it: the first
# document from spec/lib/caracal/footnotes_spec.rb:52 becomes
# caracal/footnotes_spec.rb-52-1.docx.
module OoxmlDump
  COUNTS = Hash.new(0)

  def render
    super.tap do |buffer|
      example = RSpec.current_example
      name    = example ? example.location_rerun_argument.delete_prefix('./spec/lib/').tr(':', '-') : 'outside-example'
      path    = File.join(ENV['OOXML_DUMP_DIR'], "#{name}-#{COUNTS[name] += 1}.docx")

      FileUtils.mkdir_p File.dirname(path)
      File.binwrite path, buffer.string
    end
  end
end

Caracal::Document.prepend OoxmlDump if ENV['OOXML_DUMP_DIR']
