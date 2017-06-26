# Generated via
#  `rails generate curation_concerns:work GenericWork`
require 'rails_helper'

RSpec.describe GenericWork do
  MyAssociations = {
    inscription: 'http://purl.org/vra/hasInscription',
    date_of_work: ::RDF::Vocab::DC11.date.to_s,
    additional_credit: 'http://chemheritage.org/ns/hasCredit',
  }
  MyFields = {
    # overriden fields
    contributor: 'http://purl.org/dc/elements/1.1/contributor',
    language: 'http://purl.org/dc/elements/1.1/language',
    publisher: 'http://purl.org/dc/elements/1.1/publisher',
    resource_type: 'http://purl.org/dc/elements/1.1/type',
    rights: 'http://purl.org/dc/elements/1.1/rights',
    subject: 'http://purl.org/dc/elements/1.1/subject',
    # new fields
    additional_title: 'http://purl.org/dc/terms/alternative',
    printer: 'http://id.loc.gov/vocabulary/relators/prt',
    printer_of_plates: 'http://id.loc.gov/vocabulary/relators/pop',
    engraver: 'http://id.loc.gov/vocabulary/relators/egr',
    creator_of_work: 'http://purl.org/dc/elements/1.1/creator',
    admin_note: 'http://chemheritage.org/ns/hasAdminNote',
    division: 'http://chemheritage.org/ns/hasDivision',
    after: 'http://chemheritage.org/ns/after',
    artist: 'http://id.loc.gov/vocabulary/relators/art',
    author: 'http://id.loc.gov/vocabulary/relators/aut',
    credit_line: 'http://bibframe.org/vocab/creditsNote',
    file_creator: 'http://www.ebu.ch/metadata/ontologies/ebucore/ebucore#hasCreator',
    interviewee: 'http://id.loc.gov/vocabulary/relators/ive',
    interviewer: 'http://id.loc.gov/vocabulary/relators/ivr',
    manufacturer: 'http://id.loc.gov/vocabulary/relators/mfr',
    photographer: 'http://id.loc.gov/vocabulary/relators/pht',
    extent: 'http://chemheritage.org/ns/hasExtent',
    medium: 'http://chemheritage.org/ns/hasMedium',
    physical_container: 'http://bibframe.org/vocab/materialOrganization',
    place_of_interview: 'http://id.loc.gov/vocabulary/relators/evp',
    place_of_manufacture: 'http://id.loc.gov/vocabulary/relators/mfp',
    place_of_publication: 'http://id.loc.gov/vocabulary/relators/pup',
    place_of_creation: 'http://id.loc.gov/vocabulary/relators/prp',
    rights_holder: 'http://chemheritage.org/ns/hasRightsHolder',
    series_arrangement: 'http://bibframe.org/vocab/materialHierarchicalLevel',
  }

  let(:gf) do
    GenericWork.create(title: ['title1']) do |f|
      f.apply_depositor_metadata('dpt')
      f.creator = ['Beckett, Samuel']
      f.extent = ["infinitely long"]
      f.date_of_work_attributes = [{start: "2003", finish: "2015"}, {start:'1200', start_qualifier:'century'}]
      f.inscription_attributes = [{location: "chapter 7", text: "words"}, {location: 'place', text: 'stuff'}]
      f.additional_credit_attributes = [{role: "photographer", name: "Puffins"}, {role: 'photographer', name: 'Squirrels'}]
    end
  end

  describe 'Class behaviors' do
    # TODO: associations may have predicates as well.
    #   how to account for those without keeping a separate list?
    it 'uses a different predicate for each field' do
      f = GenericWork.new
      predicates = f.resource.send(:fields).map do |attr|
        GenericWork.reflect_on_property(attr).predicate.to_s
      end
      predicates << MyAssociations.values
      dup = predicates.select{ |element| predicates.count(element) > 1 }
      expect(dup).to be_empty
    end

    it 'uses the right predicate for new and overriden properties' do
      MyFields.each do |field_name, uri|
        predicate = GenericWork.reflect_on_property(field_name).predicate.to_s
        expect(predicate).to eq uri
      end
    end

    it 'uses the right predicate for new and overriden associations' do
      MyAssociations.each do |field_name, uri|
        predicate = GenericWork.reflect_on_association(field_name).predicate.to_s
        expect(predicate).to eq uri
      end
    end

    it 'uses custom indexer' do
      expect(GenericWork.indexer).to eq CHF::GenericWorkIndexer
    end
  end

  describe 'Correctly populates fields' do

    it 'pre-populates credit line' do
      expect(gf.credit_line).to eq ['Courtesy of CHF Collections']
    end

    it 'has a single creator' do
      expect(gf.creator.count).to eq 1
      expect(gf.creator).to include 'Beckett, Samuel'
    end

    it 'has a toc' do
      expect(gf.extent).to eq ["infinitely long"]
    end

    describe "with nested Dates" do
      it "retrieves a TimeSpan object" do
        expect(GenericWork.find(gf.id).date_of_work.count).to eq 2
        expect(gf.date_of_work.first).to be_kind_of TimeSpan
      end
    end

    describe "with Nested Inscriptions" do
      it "uses Inscription class" do
        expect(gf.inscription.first).to be_kind_of Inscription
      end

      it "finds the nested attributes" do
        expect(GenericWork.find(gf.id).inscription.count).to eq 2
      end
    end

    describe "with Nested additional credit" do
      it "uses Credit class" do
        expect(gf.additional_credit.first).to be_kind_of Credit
      end

      it "finds the nested attributes" do
        expect(GenericWork.find(gf.id).additional_credit.count).to eq 2
      end
    end

    describe "illegal representative_id" do
      before do
        gf.representative = FactoryGirl.create(:file_set)
      end
      it "is not valid" do
        expect(gf.save).to be(false)
        expect(gf.errors.messages.keys).to include(:representative_id)
      end
    end

    describe "illegal thumbnail_id" do
      before do
        gf.thumbnail = FactoryGirl.create(:file_set)
      end
      it "is not valid" do
        expect(gf.save).to be(false)
        expect(gf.errors.messages.keys).to include(:thumbnail_id)
      end
    end
  end
end
