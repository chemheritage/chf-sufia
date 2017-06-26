require 'rails_helper'

RSpec.describe CHF::FileSetIndexer do
  let(:mock_file) {
      mock_model('MockFile',
                 id: 'totally_a_file_id',
                 # test fails if we don't include all these:
                 mime_type:         'text/plain',
                 format_label:      [],
                 file_size:         [],
                 height:            [],
                 width:             [],
                 page_count:        [],
                 file_title:        [],
                 original_checksum: [],
                 digest:            [],
                 duration:          [],
                 sample_rate:       []
                )
  }
  let(:file_set) { FactoryGirl.create(:file_set) }
  let(:indexer) { described_class.new(file_set) }

  describe '#generate_solr_document' do
    before do
      allow(file_set).to receive(:original_file).and_return(mock_file)
    end
    let(:solr_doc) { indexer.generate_solr_document }

    it "indexes the original_file id" do
      expect(solr_doc[ActiveFedora.index_field_mapper.solr_name('original_file_id')]).to eq 'totally_a_file_id'
    end
  end
end
