# Generated via
#  `rails generate curation_concerns:work GenericWork`
module CurationConcerns
  class GenericWorkForm < Sufia::Forms::WorkForm
    include ::WorkFormBehavior

    # this list of terms is used for:
    #   allowing the fields to be edited
    #   TODO: dry this up? was previous in a presenter. do something like
    #   https://github.com/aic-collections/aicdams-lakeshore/blob/cf197cab2b2f65f0841cbc61573ed8ef7c576c48/app/presenters/work_presenter.rb?
    def self.chf_terms
      [:title,
        :additional_title,
        :identifier, :maker,
        :provenance,
        :date_of_work,
        :place,
        :resource_type, :genre_string,
        :medium,
        :extent,
        :language,
        :description,
        :inscription,
        :digitization_funder,
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
        :file_creator,
        :admin_note,
      ]
    end

    self.model_class = ::GenericWork

    self.terms += chf_terms
    self.required_fields = [:title, :identifier]

    def primary_terms
      self.class.chf_terms
    end

  end
end
