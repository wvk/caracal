require 'spec_helper'

describe Caracal::Core::Models::ThemeColorModel do
  # values of ST_ThemeColor
  st_theme_colors = %i(dark1 light1 dark2 light2 accent1 accent2 accent3 accent4 accent5 accent6
                       hyperlink followedHyperlink background1 text1 background2 text2 none)

  describe '.ref' do
    st_theme_colors.each do |ref|
      it "accepts #{ref}" do
        model = described_class.new ref
        expect([model.valid?, model.theme_color_ref]).to eq [true, ref]
      end
    end

    { visited_hyperlink: :followedHyperlink, followed_hyperlink: :followedHyperlink, background: :background1, 'accent1' => :accent1 }.each do |name, ref|
      it "maps #{name} to #{ref}" do
        expect(described_class.new(ref: name).theme_color_ref).to eq ref
      end
    end

    it { expect(described_class.new(:visited).valid?).to eq false }
  end

  describe 'rendering' do
    let(:ns)       { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
    let(:document) { Caracal::Document.new }
    let(:xml)      { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(document) }

    before do
      document.p { text 'visited', theme_color: :visited_hyperlink, theme_bgcolor: :background2 }
    end

    it { expect(xml.at_xpath('//w:r/w:rPr/w:color', ns)['w:themeColor']).to eq 'followedHyperlink' }
    it { expect(xml.at_xpath('//w:r/w:rPr/w:shd', ns)['w:themeColor']).to eq 'background2' }
  end

  describe 'on a model' do
    it { expect { Caracal::Document.new.p { theme_color :visited } }.to raise_error(Caracal::Errors::InvalidModelError) }
  end
end
