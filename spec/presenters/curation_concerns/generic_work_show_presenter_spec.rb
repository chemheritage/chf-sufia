require 'rails_helper'

RSpec.describe CurationConcerns::GenericWorkShowPresenter do
  let(:presenter) { described_class.new(solr_document, ability) }
  let(:solr_document) { SolrDocument.new(work.to_solr) }
  let(:ability) { double "Ability" }
  let(:work) do
    FactoryGirl.create(:generic_work).tap do |w|
      w.ordered_members << fileset
      w.ordered_members << fileset2
      w.representative = fileset2
      w.thumbnail = fileset2
      w.save
    end
  end
  let(:fileset) { FactoryGirl.create(:file_set, title: ["adventure_time.txt"], content: StringIO.new("Algebraic!")) }
  let(:fileset2) { FactoryGirl.create(:file_set, title: ["adventure_time_2.txt"], content: StringIO.new("Mathematical!")) }

  describe '#riiif_file_id' do
    it "returns representative fileset's original file id" do
      expect(presenter.riiif_file_id).to be_a String
      expect(presenter.riiif_file_id).to eq fileset2.original_file.id
    end
  end
end

