class BatchUploadForm < Sufia::Forms::BatchUploadForm
  include ::WorkFormBehavior

  # note we remove title and resource_type which would be set on a per-work basis.
  def self.chf_terms
    [ :additional_title,
      :identifier, :maker,
      :provenance,
      :date_of_work,
      :place,
      :genre_string,
      :medium,
      :extent,
      :language,
      :description,
      :inscription,
      :subject,
      :division,
      :exhibition,
      :project,
      :source,
      :series_arrangement,
      :physical_container,
      :related_url,
      :rights,
      :rights_holder,
      :credit_line,
      :additional_credit,
      :digitization_funder,
      :file_creator,
      :admin_note,
    ]
  end

  self.terms += chf_terms
  self.required_fields = [:identifier]

  def primary_terms
    self.class.chf_terms
  end

end
