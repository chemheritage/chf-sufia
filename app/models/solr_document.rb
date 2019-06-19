# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document
  include BlacklightOaiProvider::SolrDocument

  include Blacklight::Gallery::OpenseadragonSolrDocument

  # Adds CurationConcerns behaviors to the SolrDocument.
  include CurationConcerns::SolrDocumentBehavior
  # Adds Sufia behaviors to the SolrDocument.
  include Sufia::SolrDocumentBehavior



  # self.unique_key = 'id'

  # Email uses the semantic field mappings below to generate the body of an email.
  SolrDocument.use_extension(Blacklight::Document::Email)

  # SMS uses the semantic field mappings below to generate the body of an SMS email.
  SolrDocument.use_extension(Blacklight::Document::Sms)

  # DublinCore uses the semantic field mappings below to assemble an OAI-compliant Dublin Core document
  # Semantic mappings of solr stored fields. Fields may be multi or
  # single valued. See Blacklight::Document::SemanticFields#field_semantics
  # and Blacklight::Document::SemanticFields#to_semantic_values
  # Recommendation: Use field names from Dublin Core
  use_extension(Blacklight::Document::DublinCore)

  # Do content negotiation for AF models.

  use_extension( Hydra::ContentNegotiation )

  def genre_string
    self[Solrizer.solr_name('genre_string')]
  end
  def medium
    self[Solrizer.solr_name('medium')]
  end
  def physical_container
    self[Solrizer.solr_name('physical_container')]
  end
  def creator_of_work
    self[Solrizer.solr_name('creator_of_work')]
  end
  def after
    self[Solrizer.solr_name('after')]
  end
  def artist
    self[Solrizer.solr_name('artist')]
  end
  def attributed_to
    self[Solrizer.solr_name('attributed_to')]
  end
  def author
    self[Solrizer.solr_name('author')]
  end
  def addressee
    self[Solrizer.solr_name('addressee')]
  end
  def editor
    self[Solrizer.solr_name('editor')]
  end
  def engraver
    self[Solrizer.solr_name('engraver')]
  end
  def interviewee
    self[Solrizer.solr_name('interviewee')]
  end
  def interviewer
    self[Solrizer.solr_name('interviewer')]
  end
  def manner_of
    self[Solrizer.solr_name('manner_of')]
  end
  def school_of
    self[Solrizer.solr_name('school_of')]
  end
  def manufacturer
    self[Solrizer.solr_name('manufacturer')]
  end
  def photographer
    self[Solrizer.solr_name('photographer')]
  end
  def printer
    self[Solrizer.solr_name('printer')]
  end
  def printer_of_plates
    self[Solrizer.solr_name('printer_of_plates')]
  end
  def provenance
    self[Solrizer.solr_name('provenance')]
  end
  def place_of_interview
    self[Solrizer.solr_name('place_of_interview')]
  end
  def place_of_manufacture
    self[Solrizer.solr_name('place_of_manufacture')]
  end
  def place_of_publication
    self[Solrizer.solr_name('place_of_publication')]
  end
  def place_of_creation
    self[Solrizer.solr_name('place_of_creation')]
  end
  def extent
    self[Solrizer.solr_name('extent')]
  end
  def division
    self[Solrizer.solr_name('division')]
  end
  def exhibition
    self[Solrizer.solr_name('exhibition')]
  end
  def project
    self[Solrizer.solr_name('project')]
  end
  def source
    self[Solrizer.solr_name('source')]
  end
  def series_arrangement
    self[Solrizer.solr_name('series_arrangement')]
  end
  def rights_holder
    self[Solrizer.solr_name('rights_holder')]
  end
  def credit_line
    self[Solrizer.solr_name('credit_line')]
  end
  def additional_credit
    self[Solrizer.solr_name('additional_credit')]
  end
  def file_creator
    self[Solrizer.solr_name('file_creator')]
  end
  def admin_note
    self[Solrizer.solr_name('admin_note')]
  end
  def inscription
    self[Solrizer.solr_name('inscription')]
  end
  def date_of_work
    self[Solrizer.solr_name('date_of_work')]
  end
  def additional_title
    self[Solrizer.solr_name('additional_title')]
  end
  def original_file_id
    # should be a single value but sometimes comes back as an array not sure why
    Array.wrap(self[Solrizer.solr_name('original_file_id')]).first
  end
  def thumbnail_path
    self['thumbnail_path_ss']
  end

  # the gems blacklight_oai_provider and oai end up calling this, we're gonna
  # just take it over completely and not call super, to use our own implementation.
  def to_oai_dc
    CHF::OaiDcSerialization.new(self).to_oai_dc
  end
end
