require 'spec_helper'

describe Caracal::Core::Sections do
  subject { Caracal::Document.new }

  let(:section_class) { Caracal::Core::Models::SectionModel }
  let(:landscape)     { { width: 15840, height: 12240, orientation: :landscape } }


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe '.section' do
    it 'closes the section before it and its own' do
      subject.p 'portrait'
      model = subject.section(page_size: landscape) { p 'landscape' }
      subject.p 'portrait again'

      expect(subject.contents.map(&:class)).to eq [
        Caracal::Core::Models::ParagraphModel, section_class,
        Caracal::Core::Models::ParagraphModel, section_class,
        Caracal::Core::Models::ParagraphModel
      ]
      expect(subject.contents[3]).to equal model
      expect(subject.contents[1]).to be_document_level
      expect(model).not_to be_document_level
    end

    it 'adds no section before one at the start' do
      subject.section { p 'first' }
      expect(subject.contents.grep(section_class).size).to eq 1
    end

    it 'adds no section between two in a row' do
      subject.p 'before'
      subject.section { p 'one' }
      subject.section { p 'two' }
      expect(subject.contents.map {|m| m.is_a?(section_class) ? :section : :content }).to eq %i(content section content section content section)
    end

    it 'leaves the document as it was when the block adds nothing' do
      subject.p 'before'
      subject.section(page_size: landscape) {}
      subject.section(page_size: landscape)
      expect(subject.contents.size).to eq 1
    end

    it 'evaluates a block without an argument on the document' do
      subject.section { p 'inside' }
      expect(subject.contents.first.plain_text).to eq 'inside'
    end

    it 'yields the document to a block with an argument' do
      subject.section {|docx| docx.p 'inside' }
      expect(subject.contents.first.plain_text).to eq 'inside'
    end

    it 'lists the sections, ending with one with the document settings' do
      subject.p 'before'
      model = subject.section { p 'inside' }
      subject.p 'after'
      expect(subject.sections.size).to eq 3
      expect(subject.sections[1]).to equal model
      expect(subject.sections.last).to be_document_level
    end

    it 'ends the list of sections with the last section of the contents' do
      model = subject.section { p 'inside' }
      expect(subject.sections).to eq [model]
    end

    it 'forgets the current section after the block, also when it raises' do
      subject.section { p 'inside' }
      expect(subject.current_section).to be_nil
      expect { subject.section { raise ArgumentError } }.to raise_error ArgumentError
      expect(subject.current_section).to be_nil
    end
  end

  describe 'settings' do
    before do
      subject.page_size width: 11906, height: 16838
      subject.page_margins left: 1000, right: 900
      subject.page_columns 2, spacing: 400
    end

    it 'takes the document settings when none are given' do
      model = subject.section { p 'a' }
      expect([model.page_width, model.page_height, model.page_orientation]).to eq [11906, 16838, 'portrait']
      expect([model.page_margin_top, model.page_margin_bottom, model.page_margin_left, model.page_margin_right]).to eq [1440, 1440, 1000, 900]
      expect([model.page_column_count, model.page_column_spacing]).to eq [2, 400]
    end

    it 'keeps the dimensions and sides not given' do
      model = subject.section(page_size: { orientation: :landscape }, page_margins: { top: 720 }) { p 'a' }
      expect([model.page_width, model.page_height, model.page_orientation]).to eq [11906, 16838, 'landscape']
      expect([model.page_margin_top, model.page_margin_bottom, model.page_margin_left, model.page_margin_right]).to eq [720, 1440, 1000, 900]
    end

    it 'takes a column count' do
      model = subject.section(columns: 3) { p 'a' }
      expect([model.page_column_count, model.page_column_spacing]).to eq [3, 720]
    end

    it 'takes a column count and spacing' do
      model = subject.section(columns: { count: 1 }) { p 'a' }
      expect(model.page_column_count).to eq 1
      model = subject.section(columns: { count: 2, spacing: 100 }) { p 'a' }
      expect([model.page_column_count, model.page_column_spacing]).to eq [2, 100]
    end

    it 'checks the margins against the section page' do
      expect { subject.section(page_size: { width: 3000, height: 3000 }, page_margins: { top: 500, bottom: 500, left: 500, right: 500 }) { p 'a' } }.not_to raise_error
    end

    it 'leaves the document settings alone' do
      subject.section(page_size: landscape, page_margins: { top: 100 }, columns: 1) { p 'a' }
      expect([subject.page_width, subject.page_margin_top, subject.page_column_count]).to eq [11906, 1440, 2]
    end
  end

  describe 'validation' do
    def section(**options)
      subject.section(**options) { p 'a' }
    end

    it { expect { section(size: landscape) }.to raise_error Caracal::Errors::InvalidModelError, /page_size, page_margins, columns/ }
    it { expect { section(page_size: :a4) }.to raise_error Caracal::Errors::InvalidModelError, /page_size takes a hash/ }
    it { expect { section(page_size: { width: 0 }) }.to raise_error Caracal::Errors::InvalidModelError, /width/ }
    it { expect { section(page_margins: { left: 0 }) }.to raise_error Caracal::Errors::InvalidModelError, /page_margins/ }
    it { expect { section(page_margins: { left: 6000, right: 6240 }) }.to raise_error Caracal::Errors::InvalidModelError, /smaller than the page size/ }
    it { expect { section(page_size: { height: 2800 }) }.to raise_error Caracal::Errors::InvalidModelError, /smaller than the page size/ }
    it { expect { section(columns: 46) }.to raise_error Caracal::Errors::InvalidModelError, /1 to 45/ }
    it { expect { section(columns: 'two') }.to raise_error Caracal::Errors::InvalidModelError, /1 to 45/ }
    it { expect { section(columns: { count: 2, gap: 100 }) }.to raise_error Caracal::Errors::InvalidModelError, /count and spacing/ }
    it { expect { section(columns: { count: 2, spacing: 9360 }) }.to raise_error Caracal::Errors::InvalidModelError, /fit between the page margins/ }
    it { expect { section(header: 'Header') }.to raise_error Caracal::Errors::InvalidModelError, /header takes a block, a Caracal::Header/ }
    it { expect { section(header: {}) }.to raise_error Caracal::Errors::InvalidModelError, /header takes/ }
    it { expect { section(header: { even: -> {} }) }.to raise_error Caracal::Errors::InvalidModelError, /:default and :first/ }
    it { expect { section(footer: subject.header) }.to raise_error Caracal::Errors::InvalidModelError, /footer takes a block, a Caracal::Footer/ }
    it { expect { section(different_first_page: 'yes') }.to raise_error Caracal::Errors::InvalidModelError, /true or false/ }

    it 'raises for a section inside another' do
      expect { subject.section { section { p 'nested' } } }.to raise_error Caracal::Errors::InvalidModelError, /nested/
    end

    it 'raises before adding anything' do
      subject.p 'before'
      expect { section(page_size: { width: 0 }) }.to raise_error Caracal::Errors::InvalidModelError
      expect(subject.contents.size).to eq 1
    end
  end

  describe 'headers and footers' do
    it 'makes a part of each given block, header and footer' do
      given = Caracal::Header.new(document: subject) { p 'given' }
      model = subject.section(header: { default: -> { p 'block' }, first: given }, footer: ->(f) { f.p 'footer' }) { p 'a' }

      expect(model.headers.keys).to eq %i(default first)
      expect(model.headers.values).to all be_a Caracal::Header
      expect(model.headers[:default].contents.map(&:plain_text)).to eq ['block']
      expect(model.headers[:first]).not_to equal given
      expect(model.headers[:first].source).to equal given
      expect(model.headers[:first].type).to eq :first
      expect(model.footers[:default].contents.map(&:plain_text)).to eq ['footer']
      expect(model.footers[:default]).to be_a Caracal::Footer
    end

    it 'has a different first page when asked or given a first-page part' do
      expect(subject.section(different_first_page: true) { p 'a' }.title_page?(false)).to eq true
      expect(subject.section(footer: { first: -> {} }) { p 'a' }.title_page?(false)).to eq true
      expect(subject.section(footer: { first: -> {} }, different_first_page: false) { p 'a' }.title_page?(false)).to eq false
      expect(subject.section { p 'a' }.title_page?(false)).to eq false
    end

    it 'follows the document in the first section' do
      subject.header(first: true)
      model = subject.section { p 'a' }
      expect(model.title_page?(true)).to eq true
      expect(model.title_page?(false)).to eq false
    end
  end

  describe 'widths' do
    before do
      subject.p 'portrait'
      subject.section page_size: landscape, page_margins: { left: 720, right: 720 }, header: -> { table [['h']] } do
        table [['wide']]
        hr width: 1000, align: :right
      end
      subject.table [['narrow']]
      subject.section(columns: 2) { table [['column']] }
    end

    let(:tables) { subject.contents.grep Caracal::Core::Models::TableModel }

    it { expect(subject.page_content_width).to eq 9360 }
    it { expect(tables.map(&:table_width)).to eq [14400, 9360, 4320] }
    it { expect(subject.contents.grep(Caracal::Core::Models::RuleModel).first.rule_container_width).to eq 14400 }
    it { expect(subject.sections[1].headers[:default].page_content_width).to eq 14400 }
    it { expect(subject.sections[1].headers[:default].contents.first.table_width).to eq 14400 }
  end
end
