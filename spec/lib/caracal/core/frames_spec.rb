require 'spec_helper'

describe Caracal::Core::Frames do
  subject { Caracal::Document.new }

  let(:ns) do
    {
      'w'   => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'r'   => 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      'mc'  => 'http://schemas.openxmlformats.org/markup-compatibility/2006',
      'wp'  => 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
      'a'   => 'http://schemas.openxmlformats.org/drawingml/2006/main',
      'wps' => 'http://schemas.microsoft.com/office/word/2010/wordprocessingShape',
      'v'   => 'urn:schemas-microsoft-com:vml',
      'o'   => 'urn:schemas-microsoft-com:office:office',
      'w10' => 'urn:schemas-microsoft-com:office:word'
    }
  end

  # renders the document and returns its parts by name
  def parts(document)
    zip = Zip::File.open_buffer document.render.string
    zip.entries.to_h {|entry| [entry.name, entry.get_input_stream.read] }
  end

  def part_xml(document, name)
    Nokogiri::XML parts(document).fetch(name)
  end

  let(:xml) { part_xml subject, 'word/document.xml' }


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    # .frame
    describe '.frame' do
      let!(:size) { subject.contents.size }

      before { subject.frame(width: 2880, height: 1440) { p 'Frame text' } }

      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::FrameModel) }
      it { expect(subject.contents.last.contents.size).to eq 1 }
    end

    context 'with invalid options' do
      it { expect { subject.frame(height: 1440) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /width/) }
      it { expect { subject.frame(width: 2880) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /height/) }
      it { expect { subject.frame(width: 2880, height: 1440, wrap: :tight) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /:tight/) }
      it { expect { subject.frame(width: 2880, height: 1440, relative_to: :line) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /:line/) }
      it { expect { subject.frame(width: 2880, height: 1440, relative_to_y: :foo) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /:foo/) }
      it { expect { subject.frame(width: 2880, height: 1440, align: :justify) { p 'a' } }.to raise_error(Caracal::Errors::InvalidModelError, /:justify/) }
      it { expect { subject.frame(width: 2880, height: 1440) }.to raise_error(Caracal::Errors::InvalidModelError, /paragraph/) }
      it { expect { subject.frame(width: 2880, height: 1440, colour: 'red') { p 'a' } }.to raise_error(RuntimeError, /colour/) }
    end

    it 'is available in headers and footers' do
      subject.header { frame(width: 2880, height: 720) { p 'Header frame' } }
      subject.footer { frame(width: 2880, height: 720) { p 'Footer frame' } }

      expect(subject.header.contents.last).to be_a(Caracal::Core::Models::FrameModel)
      expect(subject.footer.contents.last).to be_a(Caracal::Core::Models::FrameModel)
    end

  end


  #-------------------------------------------------------------
  # Rendering
  #-------------------------------------------------------------

  describe 'rendering' do
    let(:alternate) { xml.at_xpath('//w:p/w:r/mc:AlternateContent', ns) }
    let(:choice)    { alternate.at_xpath('mc:Choice', ns) }
    let(:anchor)    { choice.at_xpath('w:drawing/wp:anchor', ns) }
    let(:wsp)       { anchor.at_xpath('a:graphic/a:graphicData/wps:wsp', ns) }
    let(:shape)     { alternate.at_xpath('mc:Fallback/w:pict/v:shape', ns) }
    let(:style)     { shape['style'].split(';').to_h {|declaration| declaration.split(':', 2) } }
    let(:pos_h)     { anchor.at_xpath('wp:positionH', ns) }
    let(:pos_v)     { anchor.at_xpath('wp:positionV', ns) }

    def text_of(node)
      node.xpath('.//w:t', ns).map(&:text).join
    end

    describe 'a text box' do
      before do
        subject.frame width: 2880, height: 1440, x: 7200, y: 720 do
          p 'First paragraph'
          p 'Second paragraph'
        end
      end

      it 'declares the wps namespace on the root, not as ignorable' do
        expect(xml.root.namespaces['xmlns:wps']).to eq ns['wps']
        expect(xml.root['mc:Ignorable'].to_s.split).not_to include 'wps'
      end

      it 'writes a wps shape that requires wps, with a VML fallback' do
        expect(alternate.element_children.map(&:name)).to eq %w(Choice Fallback)
        expect(choice['Requires']).to eq 'wps'
        expect(anchor.at_xpath('a:graphic/a:graphicData/@uri', ns).value).to eq ns['wps']
        expect(wsp.element_children.map(&:name)).to eq %w(cNvSpPr spPr txbx bodyPr)
        expect(wsp.at_xpath('wps:cNvSpPr/@txBox', ns).value).to eq '1'
        expect(shape['type']).to eq '#_x0000_t202'
      end

      it 'orders the anchor children as the schema does' do
        expect(anchor.element_children.map(&:name)).to eq %w(simplePos positionH positionV extent effectExtent wrapTopAndBottom docPr cNvGraphicFramePr graphic)
      end

      it 'puts the paragraphs in both text boxes' do
        expect(text_of wsp.at_xpath('wps:txbx/w:txbxContent', ns)).to eq 'First paragraphSecond paragraph'
        expect(text_of shape.at_xpath('v:textbox/w:txbxContent', ns)).to eq 'First paragraphSecond paragraph'
      end

      it 'sizes the shape in EMUs and the VML shape in points' do
        expect(anchor.at_xpath('wp:extent', ns).attributes.transform_values(&:value)).to eq('cx' => '1828800', 'cy' => '914400')
        expect(wsp.at_xpath('wps:spPr/a:xfrm/a:ext', ns).attributes.transform_values(&:value)).to eq('cx' => '1828800', 'cy' => '914400')
        expect(style.values_at('width', 'height', 'margin-left', 'margin-top')).to eq %w(144pt 72pt 360pt 36pt)
      end

      it 'has neither border nor fill and no inner margins' do
        expect(wsp.at_xpath('wps:spPr/a:noFill', ns)).to be_truthy
        expect(wsp.at_xpath('wps:spPr/a:ln/a:noFill', ns)).to be_truthy
        expect(wsp.at_xpath('wps:bodyPr', ns).attributes.slice('lIns', 'tIns', 'rIns', 'bIns').transform_values(&:value)).to eq('lIns' => '0', 'tIns' => '0', 'rIns' => '0', 'bIns' => '0')
        expect(%w(filled stroked).map {|a| shape[a] }).to eq %w(f f)
        expect(shape.at_xpath('v:textbox/@inset', ns).value).to eq '0,0,0,0'
      end

      it 'keeps the body text 8pt away' do
        expect(%w(distT distB distL distR).map {|a| anchor[a] }).to eq %w(101600) * 4
        expect(%w(left top right bottom).map {|side| style["mso-wrap-distance-#{side}"] }).to eq %w(8pt) * 4
      end

      it 'renders the same twice' do
        first, second = 2.times.map { parts(subject).values_at 'word/document.xml', 'word/_rels/document.xml.rels', 'word/numbering.xml' }
        expect(second).to eq first
      end
    end

    describe 'anchor options' do
      context 'by default' do
        before { subject.frame(width: 2880, height: 1440, align: :right) { p 'a' } }

        it { expect(pos_h['relativeFrom']).to eq 'page' }
        it { expect(pos_h.at_xpath('wp:align', ns).text).to eq 'right' }
        it { expect(pos_v['relativeFrom']).to eq 'page' }
        it { expect(pos_v.at_xpath('wp:align', ns).text).to eq 'top' }
        it { expect(anchor.at_xpath('wp:wrapTopAndBottom', ns)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'false' }
        it { expect(style.values_at('mso-position-horizontal', 'mso-position-horizontal-relative')).to eq %w(right page) }
        it { expect(style.values_at('mso-position-vertical', 'mso-position-vertical-relative')).to eq %w(top page) }
        it { expect(style.keys).not_to include 'margin-left', 'margin-top' }
        it { expect(shape.at_xpath('w10:wrap/@type', ns).value).to eq 'topAndBottom' }
      end

      context 'with offsets' do
        before do
          subject.frame width: 2880, height: 1440 do
            x           1440
            y           -720
            relative_to :margin
            wrap        :square

            p 'a'
          end
        end

        it { expect(pos_h['relativeFrom']).to eq 'margin' }
        it { expect(pos_h.at_xpath('wp:posOffset', ns).text).to eq '914400' }
        it { expect(pos_v['relativeFrom']).to eq 'margin' }
        it { expect(pos_v.at_xpath('wp:posOffset', ns).text).to eq '-457200' }
        it { expect(anchor.at_xpath('wp:wrapSquare', ns)['wrapText']).to eq 'bothSides' }
        it { expect(style.values_at('margin-left', 'margin-top')).to eq %w(72pt -36pt) }
        it { expect(style.values_at('mso-position-horizontal', 'mso-position-vertical')).to eq %w(absolute absolute) }
        it { expect(style.values_at('mso-position-horizontal-relative', 'mso-position-vertical-relative')).to eq %w(margin margin) }
        it { expect(shape.at_xpath('w10:wrap/@type', ns).value).to eq 'square' }
      end

      {
        page:      %w(page page page page),
        margin:    %w(margin margin margin margin),
        column:    %w(column margin text margin),
        paragraph: %w(column paragraph text text)
      }.each do |relative_to, (h, v, vml_h, vml_v)|
        context "relative to #{relative_to}" do
          before { subject.frame(width: 2880, height: 1440, x: 0, y: 0, relative_to: relative_to) { p 'a' } }

          it { expect([pos_h['relativeFrom'], pos_v['relativeFrom']]).to eq [h, v] }
          it { expect(style.values_at('mso-position-horizontal-relative', 'mso-position-vertical-relative')).to eq [vml_h, vml_v] }
        end
      end

      context 'with separate references per axis' do
        before { subject.frame(width: 2880, height: 1440, relative_to: :margin, relative_to_x: :page, relative_to_y: :paragraph) { p 'a' } }

        it { expect([pos_h['relativeFrom'], pos_v['relativeFrom']]).to eq %w(page paragraph) }
        it { expect(style.values_at('mso-position-horizontal-relative', 'mso-position-vertical-relative')).to eq %w(page text) }
      end

      context 'in front of text' do
        before { subject.frame(width: 2880, height: 1440, wrap: :none) { p 'a' } }

        it { expect(anchor.at_xpath('wp:wrapNone', ns)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'false' }
        it { expect(style['z-index'].to_i).to be > 0 }
        it { expect(shape.at_xpath('w10:wrap/@type', ns).value).to eq 'none' }
      end

      context 'behind text' do
        before { subject.frame(width: 2880, height: 1440, wrap: :behind) { p 'a' } }

        it { expect(anchor.at_xpath('wp:wrapNone', ns)).to be_truthy }
        it { expect(anchor['behindDoc']).to eq 'true' }
        it { expect(style['z-index'].to_i).to be < 0 }
        it { expect(shape.at_xpath('w10:wrap/@type', ns).value).to eq 'none' }
      end
    end

    describe 'with images and other frames' do
      let(:xml)       { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(subject) }
      let(:anchors)   { xml.xpath('//wp:anchor', ns) }
      let(:doc_pr)    { xml.xpath('//mc:Choice//wp:docPr | //w:drawing[not(ancestor::mc:AlternateContent)]//wp:docPr', ns).map {|n| n['id'] } }
      let(:shapes)    { xml.xpath('//v:shape', ns) }

      before do
        subject.img 'image.png', width: 10, height: 10, anchor: true
        2.times { subject.frame(width: 2880, height: 1440) { p 'a' } }
      end

      it { expect(anchors.map {|n| n['relativeHeight'] }).to eq %w(1 2 3) }
      it { expect(doc_pr.uniq).to eq doc_pr }
      it { expect(doc_pr.size).to eq 3 }
      it { expect(shapes.map {|n| n['o:spid'] }.uniq.size).to eq 2 }

      it 'defines the VML text box shape type once' do
        expect(xml.xpath('//v:shapetype', ns).map {|n| n['id'] }).to eq %w(_x0000_t202)
      end
    end

    describe 'content' do
      before do
        subject.frame width: 2880, height: 2880 do
          p do
            text 'See '
            link 'the source', 'https://example.com/frame'
            footnote 'A footnote, left out.'
          end
          ol { li 'Item' }
          table [['A', 'B']]
        end
        subject.p 'Body'
      end

      let(:links)     { xml.xpath('//w:hyperlink', ns).map {|n| n['r:id'] }.uniq }
      let(:rel)       { subject.relationships.find {|r| r.formatted_id == links.first } }
      let(:num_ids)   { xml.xpath('//w:numPr/w:numId/@w:val', ns).map(&:value).uniq }
      let(:numbering) { part_xml subject, 'word/numbering.xml' }

      it 'links from both text boxes through one relationship of the document' do
        expect(xml.xpath('//w:hyperlink', ns).size).to eq 2
        expect(links.size).to eq 1
        expect(rel.relationship_target).to eq 'https://example.com/frame'
      end

      it 'numbers the list once' do
        expect(num_ids.size).to eq 1
        expect(numbering.xpath('//w:num/@w:numId', ns).map(&:value)).to eq num_ids
      end

      it 'holds the table in both text boxes' do
        expect(xml.xpath('//w:txbxContent/w:tbl', ns).size).to eq 2
        expect(xml.xpath('//w:txbxContent/w:tbl/w:tblPr/w:tblW/@w:w', ns).map(&:value)).to eq %w(2880 2880)
      end

      it 'leaves footnotes out' do
        expect(xml.at_xpath('//w:footnoteReference', ns)).to be_nil
        expect(parts(subject).keys).not_to include 'word/footnotes.xml'
      end
    end

    describe 'in a header' do
      before do
        subject.header do
          frame width: 2880, height: 720, y: 360, align: :right do
            p { link 'header link', 'https://example.com/header' }
          end
        end
        subject.p { link 'body link', 'https://example.com/body' }
      end

      let(:header)      { part_xml subject, 'word/header1.xml' }
      let(:header_rels) { Nokogiri::XML(parts(subject).fetch 'word/_rels/header1.xml.rels').remove_namespaces! }
      let(:link_id)     { header.at_xpath('//mc:Choice//w:hyperlink/@r:id', ns).value }

      it 'declares the wps namespace on the header' do
        expect(header.root.namespaces['xmlns:wps']).to eq ns['wps']
      end

      it 'writes the frame into the header' do
        expect(header.at_xpath('//mc:Choice[@Requires="wps"]//wps:txbx//w:t', ns).text).to eq 'header link'
        expect(header.at_xpath('//mc:Fallback//v:shapetype', ns)).to be_truthy
      end

      it 'resolves the link in the header part' do
        expect(header_rels.at_xpath("//Relationship[@Id='#{link_id}']/@Target").value).to eq 'https://example.com/header'
        expect(header.at_xpath('//mc:Fallback//w:hyperlink/@r:id', ns).value).to eq link_id
      end
    end
  end

end
