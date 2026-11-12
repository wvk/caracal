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

    # hex values of the default theme
    it { expect(xml.at_xpath('//w:r/w:rPr/w:color', ns)['w:val']).to eq '00539B' }
    it { expect(xml.at_xpath('//w:r/w:rPr/w:shd', ns)['w:color']).to eq 'FFFFFF' }

    context 'with a document theme' do
      let(:styles) { Nokogiri::XML Caracal::Renderers::StylesRenderer.render(document) }

      before do
        document.theme do
          color_dark1   '001122'
          color_accent1 'ff0000'
          color_accent2 '0000ff'
        end
        document.style id: 'Themed', name: 'themed', theme_color: :dark1, theme_bgcolor: :accent1
        document.p { text 'accent', theme_color: :accent2, theme_bgcolor: :accent1 }
        document.p { text 'explicit', theme_color: { ref: :accent2, color: '123456' } }
        document.p { text 'none', theme_color: :none }
        document.p('bordered') { border_top theme_color: :accent2 }
      end

      def run(text)
        xml.at_xpath("//w:r[w:t='#{text}']/w:rPr", ns)
      end

      it { expect(run('accent').at_xpath('w:color', ns).attributes.transform_values(&:value)).to include('val' => '0000ff', 'themeColor' => 'accent2') }
      it { expect(run('accent').at_xpath('w:shd', ns).attributes.transform_values(&:value)).to include('color' => 'ff0000', 'themeColor' => 'accent1') }
      it { expect(run('explicit').at_xpath('w:color/@w:val', ns).value).to eq '123456' }
      it { expect(run('none').at_xpath('w:color/@w:val', ns).value).to eq 'auto' }
      it { expect(xml.at_xpath("//w:p[w:r/w:t='bordered']/w:pPr/w:pBdr/w:top/@w:color", ns).value).to eq '0000ff' }
      it { expect(styles.at_xpath("//w:style[@w:styleId='Themed']/w:rPr/w:color/@w:val", ns).value).to eq '001122' }
      it { expect(styles.at_xpath("//w:style[@w:styleId='Themed']/w:rPr/w:shd/@w:color", ns).value).to eq 'ff0000' }
    end
  end

  describe 'tint and shade' do
    let(:ns)       { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
    let(:document) { Caracal::Document.new { theme { color_accent1 'FF0000'; color_text1 '000000' } } }
    let(:xml)      { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(document) }

    def color(text)
      xml.at_xpath("//w:r[w:t='#{text}']/w:rPr/w:color", ns).attributes.transform_values(&:value)
    end

    before do
      document.p do
        text 'tint',  theme_color: { ref: :accent1, tint: '80' }
        text 'shade', theme_color: { ref: :accent1, shade: '80' }
        text 'black', theme_color: { ref: :text1, tint: 'BF' }
        text 'given', theme_color: { ref: :accent1, tint: '80', color: '123456' }
      end
      document.p('bg') { theme_bgcolor ref: :accent1, shade: 'BF' }
    end

    # HSL luminance: tint L' = L*f + 1 - f, shade L' = L*f, f = value/255
    it { expect(color 'tint').to eq('themeColor' => 'accent1', 'themeTint' => '80', 'val' => 'FF7F7F') }
    it { expect(color 'shade').to eq('themeColor' => 'accent1', 'themeShade' => '80', 'val' => '800000') }
    it { expect(color('black')['val']).to eq '404040' }
    it { expect(color('given')['val']).to eq '123456' }
    it { expect(xml.at_xpath("//w:p[w:r/w:t='bg']/w:pPr/w:shd/@w:color", ns).value).to eq 'BF0000' }
  end

  describe 'on a model' do
    it { expect { Caracal::Document.new.p { theme_color :visited } }.to raise_error(Caracal::Errors::InvalidModelError) }
  end
end
