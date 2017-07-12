module CHF
  class FileSetIndexer < CurationConcerns::FileSetIndexer
    def generate_solr_document
      super.tap do |doc|
        if object.original_file
          doc[ActiveFedora.index_field_mapper.solr_name('original_file_id')] = object.original_file.id
        end
      end
    end
  end
end
