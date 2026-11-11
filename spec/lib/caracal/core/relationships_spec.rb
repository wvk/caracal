require 'spec_helper'

describe Caracal::Core::Relationships do
  let(:nonexisting) { Caracal::Core::Models::RelationshipModel.new target: 'footer1.xml',  type: :footer }
  let(:existing) { Caracal::Core::Models::RelationshipModel.new target: 'settings.xml', type: :setting }

  subject  { Caracal::Document.new }


  #-------------------------------------------------------------
  # Class Methods
  #-------------------------------------------------------------

  describe 'public class tests' do

    # .default_relationships
    describe '.default_relationships' do
      let(:expected) { [:font, :numbering, :setting, :style] }
      let(:actual)   { subject.class.default_relationships.map { |r| r[:type] } }

      it { expect(actual).to eq expected }
    end

  end


  #-------------------------------------------------------------
  # Public Methods
  #-------------------------------------------------------------

  describe 'public method tests' do

    #============== ATTRIBUTES =====================

    # .relationship
    describe '.relationship' do
      it 'delegates to registration method' do
        expect(subject).to receive(:register_relationship)
        subject.relationship target: 'new.gif', type: :image
      end
    end


    #============== GETTERS ========================

    # .relationships
    describe '.relationships' do
      it { expect(subject.relationships).to be_a(Array) }
    end

    # .find_relationship
    describe '.find_relationship' do
      let(:actual)  { subject.find_relationship(key) }

      before do
        allow(subject).to receive(:relationships).and_return([nonexisting])
      end

      describe 'when key is registered' do
        let(:key) { nonexisting.relationship_key }

        it { expect(actual).to eq nonexisting }
      end

      describe 'when key is not registered' do
        let(:key) { existing.relationship_key }

        it { expect(actual).to eq nil }
      end
    end

    #============== REGISTRATION ========================

    # .register_relationship
    describe '.register_relationship' do
      let(:default_length) { 4 }

      describe 'when not already registered' do
        before do
          subject.register_relationship(nonexisting)
        end

        it { expect(subject.relationships.size).to eq default_length + 1 }
      end

      describe 'when already registered' do
        before do
          subject.register_relationship(existing)
        end

        it { expect(subject.relationships.size).to eq default_length }
      end
    end

    # .unregister_relationship
    describe '.unregister_relationship' do
      let(:default_length) { 4 }

      describe 'when registered' do
        before do
          subject.unregister_relationship existing.relationship_target
        end

        it { expect(subject.relationships.size).to eq default_length - 1 }
      end

      describe 'when not registered' do
        before do
          subject.unregister_relationship nonexisting.relationship_target
        end

        it { expect(subject.relationships.size).to eq default_length }
      end
    end

  end

end
