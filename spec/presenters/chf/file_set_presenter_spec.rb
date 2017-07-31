require 'rails_helper'

RSpec.describe CHF::FileSetPresenter do
  let(:solr_document) { SolrDocument.new(file_set.to_solr) }
  let(:file_set) { FactoryGirl.create(:file_set, title: ["adventure_time.txt"], content: StringIO.new("Algebraic!")) }
  let(:ability) { double "Ability" }
  let(:presenter) { described_class.new(solr_document, ability) }

  describe '#representative_file_id' do
    it "equals file set's original_file id" do
      expect(presenter.representative_file_id).to be_a String
      expect(presenter.representative_file_id).to eq file_set.original_file.id
    end

    context "when it doesn't find the value in solr" do
      let(:solr_document) { SolrDocument.new(file_set.to_solr.tap { |solr_doc| solr_doc.delete('original_file_id_tesim') } ) }
      it "takes it from fedora" do
        expect(Rails.logger).to receive(:error)
        expect(presenter.representative_file_id).to eq file_set.original_file.id
      end
    end
  end
end
