require 'spec_helper'

describe Caracal::Renderers::XmlRenderer do
  describe '.new' do
    it { expect { described_class.new Object.new }.to raise_error(Caracal::Errors::NoDocumentError) }
    it { expect { described_class.new Caracal::Document.new }.not_to raise_error }
  end
end
