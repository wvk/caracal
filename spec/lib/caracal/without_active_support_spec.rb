require 'spec_helper'

describe 'Rendering without ActiveSupport' do
  let(:docx) do
    Caracal::Document.new do |docx|
      docx.theme do
        name 'Test Theme'
        color_accent1 'ff0000'
      end
      docx.toc
      docx.h1 'Chapter'
      docx.h2 'Section'
      docx.p 'Body', theme_color: :accent1
    end
  end

  it { expect(defined?(ActiveSupport)).to be_nil }
  it { expect(docx.use_theme?).to be true }
  it { expect(Caracal::Document.new.use_theme?).to be false }
  it { expect { docx.render }.not_to raise_error }
end
