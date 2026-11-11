require 'spec_helper'

describe Caracal::Core::CustomProperties do
  subject { Caracal::Document.new }

  let(:xml) { Nokogiri::XML Caracal::Renderers::CustomRenderer.render(subject) }

  def rendered(type)
    node = xml.at_xpath "//vt:#{ type }", 'vt' => 'http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes'
    node and node.text
  end

  describe '.custom_property' do
    describe 'when valid' do
      before { subject.custom_property name: 'Client', value: 'ACME', type: :text }

      it { expect(subject.custom_props.size).to eq 1 }
      it { expect(rendered :lpwstr).to eq 'ACME' }
    end

    describe 'when block given' do
      before do
        subject.custom_property do
          name  'Client'
          value 'ACME'
          type  :text
        end
      end

      it { expect(subject.custom_props.first.custom_property_name).to eq 'Client' }
    end

    [:name, :value, :type].each do |attr|
      describe "when #{ attr } missing" do
        let(:options) { { name: 'Client', value: 'ACME', type: :text }.except(attr) }

        it { expect { subject.custom_property options }.to raise_error(Caracal::Errors::InvalidModelError) }
      end
    end

    describe 'when date unparseable' do
      it { expect { subject.custom_property name: 'Due', value: 'someday', type: :date }.to raise_error(Caracal::Errors::InvalidModelError) }
    end

    describe 'when number not numeric' do
      it { expect { subject.custom_property name: 'Count', value: 'many', type: :number }.to raise_error(Caracal::Errors::InvalidModelError) }
    end
  end

  describe 'rendering' do
    before { subject.custom_property name: 'Prop', value: value, type: type }

    describe 'a date' do
      let(:type) { :date }

      describe 'given as Date' do
        let(:value) { Date.new(2024, 5, 17) }

        it { expect(rendered :filetime).to eq '2024-05-17T00:00:00Z' }
      end
      describe 'given as Time' do
        let(:value) { Time.new(2024, 5, 17, 14, 30, 0, '+02:00') }

        it { expect(rendered :filetime).to eq '2024-05-17T12:30:00Z' }
      end
      describe 'given as DateTime' do
        let(:value) { DateTime.new(2024, 5, 17, 14, 30, 0, '+02:00') }

        it { expect(rendered :filetime).to eq '2024-05-17T12:30:00Z' }
      end
      describe 'given as String' do
        let(:value) { '2024-05-17' }

        it { expect(rendered :filetime).to eq '2024-05-17T00:00:00Z' }
      end
    end

    describe 'a number' do
      let(:type) { :number }

      describe 'given as Integer' do
        let(:value) { 42 }

        it { expect(rendered :i4).to eq '42' }
      end
      describe 'given as integer String' do
        let(:value) { '42' }

        it { expect(rendered :i4).to eq '42' }
      end
      describe 'given as Float' do
        let(:value) { 3.5 }

        it { expect(rendered :r8).to eq '3.5' }
        it { expect(rendered :i4).to be_nil }
      end
      describe 'given as decimal String' do
        let(:value) { '3.5' }

        it { expect(rendered :r8).to eq '3.5' }
      end
      describe 'beyond the i4 range' do
        let(:value) { 2**31 }

        it { expect(rendered :r8).to eq '2147483648.0' }
      end
    end

    describe 'a boolean' do
      let(:type)  { :boolean }
      let(:value) { true }

      it { expect(rendered :bool).to eq 'true' }
    end

    describe 'a text' do
      let(:type)  { :text }
      let(:value) { 'ACME' }

      it { expect(rendered :lpwstr).to eq 'ACME' }
    end
  end
end
