# This stands in for an object to be created from the BatchUploadForm.
# It should never actually be persisted in the repository.
# The properties on this form should be copied to a real work type.
class BatchUploadItem < ActiveFedora::Base
  include ::CurationConcerns::WorkBehavior
  include Sufia::WorkBehavior
  include GenericMetadata

  # This mocks out the behavior of Hydra::PCDM::PcdmBehavior
  def in_collection_ids
    []
  end

  def create_or_update
    raise "This is a read only record"
  end
end
