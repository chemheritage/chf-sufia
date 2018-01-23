module CHF
  class CollectionShowPresenter < Sufia::CollectionPresenter
    # object-less class function so we can use it over in Blackight-based views
    # and presenters insteed of this sufia-based one. :(
    def self.thumbnail_src(solr_document, default: 'default_collection.svg')
      relative_path = solr_document.first(Solrizer.solr_name('representative_image_path', :displayable)).presence || default
      relative_path ? "collections/#{relative_path}" : ""
    end

    # returns arg that can be passed to 'image_tag'
    # will return default image if needed, or pass `default: nil` or your own path
    def thumbnail_src(default: 'default_collection.svg')
      self.class.thumbnail_src(self.solr_document, default: default)
    end

    def needs_permission_badge?
      solr_document.visibility != Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
    end

    def urls_to_catalog
      return [] unless @solr_document.related_url.present?
      @urls_to_catalog ||= @solr_document.related_url.find_all do |url|
        url.start_with?("http://othmerlib.chemheritage.org/record=") || url.start_with?("http://othmerlib.sciencehistory.org/record=")
      end
    end



  end
end
