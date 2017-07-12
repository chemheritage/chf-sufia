require 'rails_helper'

RSpec.describe CHF::GenericWorkIndexer do
  let (:work) do
    FactoryGirl.create(:generic_work, dates_of_work: []).tap do |w|
      w.physical_container = "b2|f3|v4|p5|g234"
      w.date_of_work_attributes = [{start: "2003", finish: "2015"}, {start:'1200', start_qualifier:'century'}]
      w.inscription_attributes = [{location: "chapter 7", text: "words"}, {location: "place", text: "stuff"}]
      w.additional_credit_attributes = [{role: "photographer", name: "Puffins"}, {role: "photographer", name: "Squirrels"}]
      w.author = ["Bruce McMillan"]
      w.photographer = ["Bruce McMillan"]
      w.publisher = ["publishing house"]
      w.engraver = ["engraving professional"]
      w.save
    end
  end

  let(:service) { described_class.new(work) }
  let(:mapper) { ActiveFedora.index_field_mapper }
  subject(:solr_document) { service.generate_solr_document }

  it 'indexes all additional credits' do
    expect(solr_document["additional_credit_tesim"].count).to eq 2
    expect(solr_document["additional_credit_tesim"]).to include 'Photographed by Puffins'
    expect(solr_document["additional_credit_tesim"]).to include 'Photographed by Squirrels'
  end
  it 'indexes all inscriptions' do
    expect(solr_document["inscription_tesim"].count).to eq 2
    expect(solr_document["inscription_tesim"]).to include '(chapter 7) "words"'
    expect(solr_document["inscription_tesim"]).to include '(place) "stuff"'
  end
  it 'indexes all dates' do
    expect(solr_document["date_of_work_tesim"].count).to eq 2
    expect(solr_document["date_of_work_tesim"]).to include '2003 - 2015'
    expect(solr_document["date_of_work_tesim"]).to include '1200s (century)'
  end
  it 'creates a maker copy field' do
    expect(solr_document[mapper.solr_name('maker_facet', :facetable)]).not_to be nil
    expect(solr_document[mapper.solr_name('maker_facet', :facetable)]).to include 'Bruce McMillan'
    expect(solr_document[mapper.solr_name('maker_facet', :facetable)]).to include 'publishing house'
    expect(solr_document[mapper.solr_name('maker_facet', :facetable)].size).to eq 3
  end

end
