require 'rails_helper'

RSpec.describe FileSet do
  it 'uses custom indexer' do
    expect(FileSet.indexer).to eq CHF::FileSetIndexer
  end
end
