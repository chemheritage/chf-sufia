class CollectionsController < ApplicationController
  include CurationConcerns::CollectionsControllerBehavior
  include Sufia::CollectionsControllerBehavior

  include ParentLookup

  # Change any legacy cq parameters (say sent from admin search form) to :q
  before_filter ->(controller) {
    if controller.params[:cq].present?
      controller.params[:q] = controller.params.delete(:cq)
    end
  }

  self.presenter_class = CHF::CollectionShowPresenter

  layout 'chf'

  # Override to use the sort_widget from catalog, not the sufia override. What are we missing
  # from the sufia override? Not sure! But it didn't CSS style correctly.
  view_type_action = blacklight_config.index.collection_actions["view_type_group"]
  view_type_action.partial = "catalog/view_type_group" if view_type_action

  def form_class
    CollectionEditForm
  end

  def index
    documents = super
    @presenters = documents.
      map { |document| presenter_class.new(document, current_ability) }.
      sort! { |x,y| x.title.first <=> y.title.first }
  end

  def show
    super
    @parent_presenter_lookup = parent_lookup_hash(@member_docs)
  end

  protected

  # Override from curation_concerns to use ordinary 'q' instead of translating 'cq'
  # to 'q', I don't know what that was about.
  def params_for_members_query
    params.dup
  end

  # Override from curation_concerns to use ordinary 'q' instead of 'cq'
  # Queries Solr for members of the collection.
  # Populates @response and @member_docs similar to Blacklight Catalog#index populating @response and @documents
  # https://github.com/samvera/curation_concerns/blob/v1.7.8/app/controllers/concerns/curation_concerns/collections_controller_behavior.rb#L221-L227
  def query_collection_members
    @response = repository.search(query_for_collection_members)
    @member_docs = @response.documents
  end

  # Have to override method from curation_concerns to ignore facets when trying
  # to fetch collection. gah.
  # https://github.com/samvera/curation_concerns/blob/v1.7.8/app/controllers/concerns/curation_concerns/collections_controller_behavior.rb?utf8=%E2%9C%93#L177-L192
  def single_item_search_builder
    single_item_search_builder_class.new(self).with(params.except(:q, :page, :f))
  end

  # Have to override this helper method from Blacklight to tell it, no, keep the
  # search HERE in this controller, don't go over to CatalogController. Ergh.
  # https://github.com/projectblacklight/blacklight/blob/v6.7.2/app/controllers/concerns/blacklight/controller.rb#L71-L74
  def search_action_url options = {}
    url_for(options.except(:controller, :action))
  end
  helper_method :search_action_url

end
