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