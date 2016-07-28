# frozen_string_literal: true
class SolrDocument
  include Blacklight::Solr::Document
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
  def artist
    self[Solrizer.solr_name('artist')]
  end
  def author
    self[Solrizer.solr_name('author')]
  end
  def addressee
    self[Solrizer.solr_name('addressee')]
  end
  def interviewee
    self[Solrizer.solr_name('interviewee')]
  end
  def interviewer
    self[Solrizer.solr_name('interviewer')]
  end
  def manufacturer
    self[Solrizer.solr_name('manufacturer')]
  end
  def photographer
    self[Solrizer.solr_name('photographer')]
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

end
