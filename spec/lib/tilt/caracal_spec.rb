require 'spec_helper'

describe 'Tilt integration' do
  let(:template) { Tilt['report.docx.caracal'] }

  it { expect(template.name).to eq 'Tilt::CaracalTemplate' }
  it { expect(template.new { "docx.p 'Hello'" }.render).to start_with 'PK' }
end
