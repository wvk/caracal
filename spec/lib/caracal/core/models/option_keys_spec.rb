require 'spec_helper'

# Settings that upstream caracal only accepted in the block form until 1.6.0.
# BaseModel here sends every option to its setter and raises on unknown ones,
# so these check the option form keeps working.
describe 'model options' do
  it { expect(Caracal::Core::Models::ParagraphModel.new(keep_next: true).paragraph_keep_next).to eq true }
  it { expect(Caracal::Core::Models::TableModel.new(data: [['a'], ['b']], repeat_header: 1).table_repeat_header).to eq 1 }
  it { expect(Caracal::Core::Models::TableModel.new(data: [['a'], ['b']], header_rows: 1).table_repeat_header).to eq 1 }
  it { expect(Caracal::Core::Models::TableModel.new(data: [['a'], ['b']]) { header_rows 2 }.table_header_rows).to eq 2 }
  it { expect(Caracal::Core::Models::ListStyleModel.new(restart: 0).style_restart).to eq 0 }
  it { expect(Caracal::Core::Models::ImageModel.new(url: 'logo.png', ppi: 300, width: 1, height: 1).image_ppi).to eq 300 }

  it 'sizes the page number label and number with size' do
    model = Caracal::Core::Models::PageNumberModel.new(size: 24)

    expect([model.page_number_label_size, model.page_number_number_size]).to eq [24, 24]
  end

  it 'passes keep_next through the document API' do
    docx = Caracal::Document.new
    docx.p 'heading', keep_next: true

    expect(docx.contents.last.paragraph_keep_next).to eq true
  end
end
