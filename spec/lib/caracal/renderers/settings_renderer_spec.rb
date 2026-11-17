require 'spec_helper'

describe Caracal::Renderers::SettingsRenderer do
  let(:ns)     { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
  let(:compat) { Nokogiri::XML(described_class.render(document)).at_xpath('//w:compat', ns) }

  describe 'by default' do
    let(:document) { Caracal::Document.new }

    it { expect(compat.at_xpath('w:doNotExpandShiftReturn', ns)).to be_nil }
  end

  describe 'with lines before breaks left unjustified' do
    let(:document) { Caracal::Document.new {|docx| docx.justify_lines_before_breaks false } }

    it { expect(compat.xpath('*', ns).map(&:name)).to eq %w(doNotExpandShiftReturn compatSetting) }
  end
end
