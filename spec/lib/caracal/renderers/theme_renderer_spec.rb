require 'spec_helper'

describe Caracal::Renderers::ThemeRenderer do
  let(:ns)       { { 'a' => 'http://schemas.openxmlformats.org/drawingml/2006/main' } }
  let(:document) { Caracal::Document.new }
  let(:theme)    { document.theme { color_accent1 'FF0000' } }
  let(:xml)      { Nokogiri::XML described_class.render(document, theme) }

  def color(name)
    xml.at_xpath("//a:clrScheme/a:#{name}/a:srgbClr", ns)['val']
  end

  it { expect(xml.xpath('//a:clrScheme/*/a:srgbClr', ns).map { |n| n['val'] }).to all(match(/\A\h{6}\z/)) }
  it { expect(color('lt2')).to eq 'FFFFFF' }
  it { expect(color('accent1')).to eq 'FF0000' }
end
