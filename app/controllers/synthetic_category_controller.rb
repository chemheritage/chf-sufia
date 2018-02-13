# Only a 'show' action
#
# Based roughly off of Sufia/CurationConcerns CollectionController#show
# TODO link to CollectionControllerBehavior in both
class SyntheticCategoryController < ApplicationController
    # include Blacklight::AccessControls::Catalog
    include Blacklight::Base

    layout 'chf'

    copy_blacklight_config_from(::CatalogController)

    # Override to use the sort_widget from catalog, not the sufia override. What are we missing
    # from the sufia override? Not sure! But it didn't CSS style correctly.
    view_type_action = blacklight_config.index.collection_actions["view_type_group"]
    view_type_action.partial = "catalog/view_type_group" if view_type_action

    def show
      unless synthetic_category
        raise ActionController::RoutingError.new("No SyntheticCategory matches `#{params[:id]}`")
      end
      set_response # trigger setting of @response, which I think some partials need.
    end


    protected

    # Get controller to find templates in CollectionController too,
    # so we can re-use more of the sufia stuff for collection. Messy messy.
    def self.local_prefixes
      @local_prefixes ||= super.concat ['collections', 'catalog']
    end

    # Have to override this helper method from Blacklight to tell it, no, keep the
    # search HERE in this controller, don't go over to CatalogController. Ergh.
    # https://github.com/projectblacklight/blacklight/blob/v6.7.2/app/controllers/concerns/blacklight/controller.rb#L71-L74
    # used by facets and constraints and such.
    def search_action_url options = {}
      url_for(options.except(:controller, :action))
    end
    helper_method :search_action_url

    def synthetic_category
      CHF::SyntheticCategory.from_slug(params[:id])
    end
    helper_method :synthetic_category

    def search_builder
      @search_builder ||= SearchBuilder.new(self).tap { |sb| sb.synthetic_category_force = synthetic_category.category_key }
    end

    def set_response
      @response ||= repository.search( search_builder.with(params).query )
    end

    def results
      set_response
      @results ||= @response.documents
    end
    helper_method :results

    def total_count
      # improvement, cache somewhere?
      @total_count ||= repository.search( search_builder.with(params.merge(rows: 0)).query).total
    end
    helper_method :total_count


    # Override helper method to insist on :list type, that's all we
    # do here and all we have partials for.
    def document_index_view_type *args
      :list
    end
    helper_method :document_index_view_type

end
