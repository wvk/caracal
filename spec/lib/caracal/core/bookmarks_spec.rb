require 'spec_helper'

describe Caracal::Core::Bookmarks do
  subject { Caracal::Document.new }


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    # .bookmark_start
    describe '.bookmark_start' do
      let!(:size) { subject.contents.size }

      before { subject.send('bookmark_start', name: 'abc') }

      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::BookmarkModel) }
    end

    # .bookmark_end
    describe '.bookmark_end' do
      let!(:size) { subject.contents.size }

      before { subject.send('bookmark_end') }

      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::BookmarkModel) }

      it 'accepts an id' do
        expect(subject.bookmark_end(id: 's1').bookmark_id).to eq 's1'
      end
    end

  end


  #-------------------------------------------------------------
  # Rendering
  #-------------------------------------------------------------

  describe 'rendering' do
    let(:ns)  { { 'w' => 'http://schemas.openxmlformats.org/wordprocessingml/2006/main' } }
    let(:xml) { Nokogiri::XML Caracal::Renderers::DocumentRenderer.render(subject) }

    def ids(xml, element)
      xml.xpath("//w:#{element}", ns).map { |n| n['w:id'] }
    end

    def id_of(xml, name)
      xml.at_xpath("//w:bookmarkStart[@w:name='#{name}']", ns)['w:id']
    end

    context 'with the README example' do
      before do
        subject.bookmark_start id: 's1', name: 'section1'
        subject.h2 'Section Heading'
        subject.bookmark_end id: 's1'
        subject.p 'Section content.'

        subject.h2 'Section Heading'
        subject.p do
          text 'Pretend this paragraph has a lot of text and we want to bookmark '
          bookmark_start id: 'p1', name: 'phrase1'
          text 'a single phrase'
          bookmark_end id: 'p1'
          text ' inside the larger block.'
        end
      end

      it { expect(ids(xml, 'bookmarkStart')).to all(match(/\A\d+\z/)) }
      it { expect(ids(xml, 'bookmarkStart').uniq.size).to eq 2 }
      it { expect(ids(xml, 'bookmarkEnd')).to eq ids(xml, 'bookmarkStart') }
    end

    context 'with overlapping keyed bookmarks' do
      before do
        subject.bookmark_start id: 'outer', name: 'outer'
        subject.p do
          bookmark_start id: 'inner', name: 'inner'
          text 'text'
          bookmark_end id: 'outer'
        end
        subject.bookmark_end id: 'inner'
      end

      it { expect(ids(xml, 'bookmarkEnd')).to eq [id_of(xml, 'outer'), id_of(xml, 'inner')] }
      it { expect(id_of(xml, 'outer')).not_to eq id_of(xml, 'inner') }
    end

    context 'with ids at one level only' do
      before do
        subject.bookmark_start name: 'auto'
        subject.p do
          bookmark_start id: 2, name: 'para'
          text 'text'
          bookmark_end id: '2'
        end
        subject.bookmark_end
      end

      it { expect(ids(xml, 'bookmarkStart').uniq.size).to eq 2 }
      it { expect(ids(xml, 'bookmarkEnd')).to eq [id_of(xml, 'para'), id_of(xml, 'auto')] }
    end

    context 'with a reused id' do
      before do
        2.times do |i|
          subject.p do
            bookmark_start id: 'x', name: "n#{i}"
            text 'text'
            bookmark_end id: 'x'
          end
        end
      end

      it { expect(ids(xml, 'bookmarkStart').uniq.size).to eq 2 }
      it { expect(ids(xml, 'bookmarkEnd')).to eq ids(xml, 'bookmarkStart') }
    end

    context 'with an end that has no start' do
      before { subject.bookmark_end id: 'nope' }

      it { expect(ids(xml, 'bookmarkEnd')).to be_empty }
    end
  end

end
