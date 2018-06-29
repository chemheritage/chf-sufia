# frozen_string_literal: true
module GenericMetadata
  extend ActiveSupport::Concern
  included do

    # tried this as before_save, but then it didn't show up on metadata form at upload time.
    after_initialize :set_default_metadata

    # default properties that we didn't need to delete
    # Note: title is defined further down the stack but customized to be single-value in our forms
    property :label, predicate: ActiveFedora::RDF::Fcrepo::Model.downloadFilename, multiple: false
    property :relative_path, predicate: ::RDF::URI.new('http://scholarsphere.psu.edu/ns#relativePath'), multiple: false
    property :import_url, predicate: ::RDF::URI.new('http://scholarsphere.psu.edu/ns#importUrl'), multiple: false do |index|
      index.as :symbol
    end
    property :part_of, predicate: ::RDF::Vocab::DC.isPartOf
    # description is single-value (enforced by form)
    property :description, predicate: ::RDF::Vocab::DC11.description do |index|
      index.type :text
      index.as :stored_searchable
    end
    property :date_created, predicate: ::RDF::Vocab::DC.created do |index|
      index.as :stored_searchable
    end
    property :subject, predicate: ::RDF::Vocab::DC11.subject do |index|
      index.as :stored_searchable, :facetable
    end
    property :language, predicate: ::RDF::Vocab::DC11.language do |index|
      index.as :stored_searchable, :facetable
    end
    property :identifier, predicate: ::RDF::Vocab::DC.identifier do |index|
      index.as :stored_searchable
    end
    property :based_near, predicate: ::RDF::Vocab::FOAF.based_near do |index|
      index.as :stored_searchable, :facetable
    end
    property :related_url, predicate: ::RDF::RDFS.seeAlso do |index|
      index.as :stored_searchable
    end
    property :bibliographic_citation, predicate: ::RDF::Vocab::DC.bibliographicCitation do |index|
      index.as :stored_searchable
    end
    property :source, predicate: ::RDF::Vocab::DC.source do |index|
      index.as :stored_searchable
    end


    # local properties

    # sufia 6 used DC.creator and sufia 7 changed this to DC11.creator, which we were already using.
    # Is this still used by sufia internally?
    property :creator, predicate: ::RDF::Vocab::DC.creator do |index|
      index.as :stored_searchable
    end

    # makers
    property :after, predicate: ::RDF::URI.new("http://chemheritage.org/ns/after") do |index|
      index.as :stored_searchable
    end
    property :artist, predicate: ::RDF::Vocab::MARCRelators.art do |index|
      index.as :stored_searchable
    end
    property :author, predicate: ::RDF::Vocab::MARCRelators.aut do |index|
      index.as :stored_searchable
    end
    property :addressee, predicate: ::RDF::Vocab::MARCRelators.rcp do |index|
      index.as :stored_searchable
    end
    property :creator_of_work, predicate: ::RDF::Vocab::DC11.creator do |index|
      index.as :stored_searchable
    end
    property :contributor, predicate: ::RDF::Vocab::DC11.contributor do |index|
      index.as :stored_searchable
    end
    property :engraver, predicate: ::RDF::Vocab::MARCRelators.egr do |index|
      index.as :stored_searchable
    end
    property :interviewee, predicate: ::RDF::Vocab::MARCRelators.ive do |index|
      index.as :stored_searchable
    end
    property :interviewer, predicate: ::RDF::Vocab::MARCRelators.ivr do |index|
      index.as :stored_searchable
    end
    property :manner_of, predicate: ::RDF::URI.new("http://chemheritage.org/ns/mannerOfContribution") do |index|
      index.as :stored_searchable
    end
    property :manufacturer, predicate: ::RDF::Vocab::MARCRelators.mfr do |index|
      index.as :stored_searchable
    end
    property :photographer, predicate: ::RDF::Vocab::MARCRelators.pht do |index|
      index.as :stored_searchable
    end

    property :printer, predicate: ::RDF::Vocab::MARCRelators.prt do |index|
      index.as :stored_searchable
    end

    property :printer_of_plates, predicate: ::RDF::Vocab::MARCRelators.pop do |index|
      index.as :stored_searchable
    end
    property :publisher, predicate: ::RDF::Vocab::DC11.publisher do |index|
      index.as :stored_searchable
    end
    # end makers

    # places
    property :place_of_interview, predicate: ::RDF::Vocab::MARCRelators.evp do |index|
      index.as :stored_searchable
    end
    property :place_of_manufacture, predicate: ::RDF::Vocab::MARCRelators.mfp do |index|
      index.as :stored_searchable
    end
    property :place_of_publication, predicate: ::RDF::Vocab::MARCRelators.pup do |index|
      index.as :stored_searchable
    end
    property :place_of_creation, predicate: ::RDF::Vocab::MARCRelators.prp do |index|
      index.as :stored_searchable
    end
    # end places

    property :additional_title, predicate: ::RDF::Vocab::DC.alternative do |index|
      index.as :stored_searchable
    end

    property :admin_note, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasAdminNote") do |index|
      index.as :stored_searchable
    end

    property :credit_line, predicate: ::RDF::Vocab::Bibframe.creditsNote do |index|
      index.as :stored_searchable
    end

    property :division, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasDivision"), multiple: false do |index|
      index.as :stored_searchable, :facetable
    end

    property :exhibition, predicate: ::RDF::URI.new("http://opaquenamespace.org/ns/exhibit") do |index|
      index.as :stored_searchable, :facetable
    end

    property :source, predicate: ::RDF::URI.new("http://purl.org/dc/elements/1.1/source") do |index|
      index.as :stored_searchable
    end

    property :file_creator, predicate: ::RDF::Vocab::EBUCore.hasCreator, multiple: false do |index|
      index.as :stored_searchable
    end

    property :genre_string, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasGenre") do |index|
      index.as :stored_searchable, :facetable
    end


    property :extent, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasExtent") do |index|
      index.as :stored_searchable
    end

    property :medium, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasMedium") do |index|
      index.as :stored_searchable, :facetable
    end
    property :physical_container, predicate: ::RDF::Vocab::Bibframe.materialOrganization, multiple: false do |index|
      index.as :stored_searchable
    end

    property :resource_type, predicate: ::RDF::Vocab::DC11.type do |index|
      index.as :stored_searchable, :facetable
    end
    property :rights, predicate: ::RDF::Vocab::DC11.rights do |index|
      index.as :stored_searchable, :facetable
    end
    property :rights_holder, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasRightsHolder"), multiple: false do |index|
      index.as :stored_searchable
    end

    property :series_arrangement, predicate: ::RDF::Vocab::Bibframe.materialHierarchicalLevel do |index|
      index.as :stored_searchable
    end

    has_and_belongs_to_many :date_of_work, predicate: ::RDF::Vocab::DC11.date, class_name: "DateOfWork"
    accepts_nested_attributes_for :date_of_work, reject_if: :all_blank, allow_destroy: true

    has_and_belongs_to_many :inscription, predicate: ::RDF::URI.new("http://purl.org/vra/hasInscription"), class_name: "Inscription"
    accepts_nested_attributes_for :inscription, reject_if: :all_blank, allow_destroy: true

    has_and_belongs_to_many :additional_credit, predicate: ::RDF::URI.new("http://chemheritage.org/ns/hasCredit"), class_name: "Credit"
    accepts_nested_attributes_for :additional_credit, reject_if: :all_blank, allow_destroy: true

    # chf edit 2016-02-01 ah
    # Override this from sufia-models/app/models/concerns/sufia/generic_file/batches.rb
    # It's meaningless to define related_files in terms of what sufia6 calls 'batches' ('UploadSets' in sufia 7)
    # However, let's not lose track of the batch_id altgoether just in case we want it for some reason later.
    # Note 2016-07: that this behavior is replaced by works related_files now pulls all sibling relationships
    # https://github.com/projecthydra/curation_concerns/blob/master/app/models/concerns/curation_concerns/file_set/belongs_to_works.rb#L27
    #def related_files
    #  []
    #end

    private

      def set_default_metadata
        self.credit_line = ['Courtesy of Science History Institute']
      end

  end
end
