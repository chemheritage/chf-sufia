# controller JUST for 'show collection' action, we make it inherit
# from CatalogController so it's easier to make it support full search with
# facets etc. But with some behavior copied from CurationConcerns::CollectionControllerBehavior
#

class CollectionsShowController < CatalogController
  include Sufia::Breadcrumbs

  layout 'chf'

  # It would make a lot more sense for this action to be 'show', and it is adapted
  # from CurationConcerns::CollectionControllerBehavior#show, but so many parts of blacklight
  # search results assume or hard-code action #index, it's a lot easier to just do that. Sorry!
  def index
    build_breadcrumbs

    presenter # load Collection presenter
    (@response, _deprecated_document_list) = search_results(params) # from blacklight Catalog#index
    @parent_presenter_lookup = parent_lookup_hash(@response.documents) # to look up parents to show, in one query
  end

  # Override from Blacklight catalog.rb to get facet id out of :facet_id,
  # so :id can continue being our parent collection id.
  # displays values and pagination links for a single facet field
  def facet
    @facet = blacklight_config.facet_fields[params[:facet_id]]
    if @facet == nil
      redirect_to collection_path
      return
    end
    @response = get_facet_field_response(@facet.key, params)
    @display_facet = @response.aggregations[@facet.key]
    @pagination = facet_paginator(@facet, @display_facet)
    respond_to do |format|
      # Draw the facet selector for users who have javascript disabled:
      format.html
      format.json
      # Draw the partial for the "more" facet modal window:
      format.js { render :layout => false }
    end
  end

  # catalog controller action method we don't want to expose
  protected :show

  protected

  def public_count
    unless defined? @public_count
      # Set up a SearchBuilder like the current one, but insisting on the non-logged-in
      # user, to get count of public objects. Just include :id param for collection,
      # no query params.
      builder = search_builder.with(params.slice(:id)).tap do |builder|
        builder.force_as_not_logged_in
        builder.rows = 0
      end

      @public_count = repository.search(builder).total
    end
    @public_count
  end
  helper_method :public_count

  def search_builder_class
    # limit just to docs in collection. Sufia overrides this so you can no longer set
    # with blacklight_config, gah.
    CurationConcerns::CollectionMemberSearchBuilder
  end

  # Get controller to find templates in CollecitonsController too,
  # so we can re-use more of the sufia stuff for collection. Messy messy.
  def self.local_prefixes
    # make sure this doens't apply to sub-classes, adding 'collections' more
    # than once in weird places. :( messy, I know.
    if controller_path == "collections_show"
      super.concat ['collections']
    else
      super
    end
  end

  def member_docs
    @member_docs ||= @response.documents
  end
  helper_method :member_docs

  def presenter
    @presenter ||= begin
      # Query Solr for the collection.
      response = repository.search(single_item_search_builder.query)
      curation_concern = response.documents.first
      raise CanCan::AccessDenied unless curation_concern
      CHF::CollectionShowPresenter.new(curation_concern, current_ability)
    end
  end
  helper_method :presenter

  def single_item_search_builder
    CurationConcerns::SingleCollectionSearchBuilder.new(self).with(params.slice(:id))
  end

  def add_breadcrumb_for_controller
    add_breadcrumb I18n.t('sufia.dashboard.my.collections'), sufia.dashboard_collections_path
  end

  def add_breadcrumb_for_action
    case action_name
    when 'show'.freeze
      add_breadcrumb presenter.to_s, main_app.polymorphic_path(presenter)
    end
  end

  # override to put the facet id in :facet_id instead of :id, so we can keep
  # :id for our parent collection id.
  def search_facet_url options = {}
    if options.has_key?(:id)
      options[:facet_id] = options.delete(:id)
    end
    super(options)
  end

  # Show breadcrumbs to all users, even if they're not logged in...
  def show_breadcrumbs?
    true
  end

  # ... but, for not-logged-in users, only show the "Back to Search Results" breacrumb.
  def build_breadcrumbs
    super
    filter_breadcrumbs(@breadcrumbs)
  end

end


