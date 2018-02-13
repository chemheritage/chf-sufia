class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior

  # Adds CurationConcerns behaviors to the application controller.
  include CurationConcerns::ApplicationControllerBehavior
  include CurationConcerns::ThemedLayoutController
  with_themed_layout '1_column'


  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  # Adds Sufia behaviors into the application controller
  include Sufia::Controller

  # Please be sure to impelement current_user and user_session. Blacklight depends on
  # these methods in order to perform user specific actions.

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  module RenderQueryConstraintOverride
    # Override to turn it into a live search box/form allowing you to change query,
    # instead of just a label
    def render_constraints_query(localized_params = params)
      # Only on catalog (user-facing), doesn't work for "my_works" admin.
      if params[:controller] == "catalog" || (["collections", "synthetic_category"].include?(params[:controller]) && params[:action] == "show")
        render "query_constraint_as_form", params: localized_params
      else
        super
      end
    end

    def query_has_constraints?(localized_params = params)
      super || localized_params[:filter_public_domain] == "1"
    end
  end
  helper RenderQueryConstraintOverride


  # Cheesy way to override Blaclight helper method with call to super possible
  module SortHelperOverrides
    def active_sort_fields
      if params[:q].present?
        super
      else
        # with no query, relevance doesn't make a lot of sense
        super.delete_if { |k| k.start_with?("score") }
      end
    end
  end
  helper SortHelperOverrides

  module ThumbOverride

    # Override of helper from Blacklight, to try to use our custom S3-stored
    # thumbnails.
    #
    # https://github.com/projectblacklight/blacklight/blob/v6.7.2/app/helpers/blacklight/catalog_helper_behavior.rb#L219-L228
    #
    # Our end-user-facing pages don't generally use this method,
    # but various diverse built-in admin pages do, in various not consistent ways, passing
    # various presenters or raw solr docs as argument. We somewhat hackily
    # try to get it to use our own presenters (which aren't so consistent
    # either), with the logic we've given them for keeping track of representative
    # ids, and our helper method for looking up thumb URL.
    def thumbnail_url(document)
      # sometimes we get something that's already a presenter, sometimes we
      # get raw solr doc. Turn it into raw solr doc, so we can wrap in presenter
      # we want.
      solr_document = document.try(:solr_document) || document

      # We want our existing presenters for their logic on representative
      # ids. Sadly, we stored things in different fields for fileset vs work,
      # and need their respective presenters in order to get a common API.
      # Have to do this kind of hacky specific for listed classes, I'm afraid.
      presenter = case solr_document.hydra_model.to_s
        when "GenericWork"
          CurationConcerns::GenericWorkShowPresenter.new(solr_document, self)
        when "FileSet"
          CHF::FileSetPresenter.new(solr_document, self)
        when "Collection"
          CHF::CollectionShowPresenter.new(solr_document, self)
      end

      # If we couldn't get a presenter just call super, although
      # it probably won't do anything useful since we're not neccesarily indexing
      # properly and default tries to get from index.
      if presenter
        member_src_attributes(member: presenter, size_key: :standard)[:src]
      else
        super
      end
    end
  end
  helper ThumbOverride
end
