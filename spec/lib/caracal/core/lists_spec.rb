require 'spec_helper'

describe Caracal::Core::Lists do
  subject { Caracal::Document.new }
  
  
  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do
    
    # .ol
    describe '.ol' do
      let!(:size) { subject.contents.size }
      
      before do 
        subject.ol do
          li 'Item 1'
        end
      end
        
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ListModel) }
    end
    
    describe '.ol with start' do
      it { expect(subject.ol(start: 3) { li 'Item 3' }.list_start).to eq 3 }
      it { expect(subject.ol { start 3; li 'Item 3' }.list_start).to eq 3 }
      it { expect(subject.ol { li 'Item 1' }.list_start).to be_nil }

      it 'raises for a negative start' do
        expect { subject.ol(start: -1) { li 'Item' } }.to raise_error(Caracal::Errors::InvalidModelError, /start must be 0 or more/)
      end

      it 'raises for a nested list with a start' do
        expect { subject.ol { li('Item') { ol(start: 3) { li 'Sub item' } } } }.to raise_error(Caracal::Errors::InvalidModelError, /start applies to top-level lists/)
      end

      it 'raises for a list without items' do
        expect { subject.ol(start: 3) }.to raise_error(Caracal::Errors::InvalidModelError, /require at least one list item/)
      end
    end

    # .ul
    describe '.ul' do
      let!(:size) { subject.contents.size }
      
      before do 
        subject.ul do
          li 'Item 1'
        end
      end
        
      it { expect(subject.contents.size).to eq size + 1 }
      it { expect(subject.contents.last).to be_a(Caracal::Core::Models::ListModel) }
    end

    # nesting depth
    describe 'nesting depth' do
      # Builds an ordered list with lists nested depth levels below it.
      def nested_ol(depth)
        deep = ->(ctx, n) { n.zero? ? ctx.li('leaf') : ctx.li("level #{depth - n}") { ol { deep.(self, n - 1) } } }
        subject.ol { deep.(self, depth) }
      end

      it 'builds nine levels' do
        expect(nested_ol(8).recursive_items.map(&:list_item_level)).to eq (0..8).to_a
      end

      it 'raises when a tenth level is built' do
        expect { nested_ol(9) }.to raise_error(Caracal::Errors::InvalidModelError, /nine levels deep \(levels 0 to 8\)/)
      end
    end

  end
  
end