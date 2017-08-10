module CHF
  # Add some things we can use for our custom UI
  class FileSetPresenter < Sufia::FileSetPresenter

    delegate :original_file_id, :original_checksum, to: :solr_document

    # Consistent API with GenericWorkShowPresenter, on show pages we often
    # only show permissoin badge if not open access.
    def needs_permission_badge?
      solr_document.visibility != Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end

    def representative_file_id
      # if it's not in solr, get it from fedora
      if original_file_id
        return original_file_id
      else
        Rails.logger.error "ERROR: Could not find FileSet #{id} original_file_id in Solr. You may need to reindex."
        return FileSet.find(id).original_file.id
      end
    end

    def representative_checksum
      # somehow coming back as array instead of single element, only sometimes
      Array(original_checksum).first
    end

    def representative_height
      height
    end

    def representative_width
      width
    end

  end
end
