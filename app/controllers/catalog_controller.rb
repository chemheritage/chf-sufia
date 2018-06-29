class CatalogController < ApplicationController
  include Hydra::Catalog
  include Hydra::Controller::ControllerBehavior
  include Sufia::Catalog
  include BlacklightRangeLimit::ControllerOverride

  include ParentLookup

  # use the standard local 'application' layout, which we've actually
  # customized based on sufia layout. Ordinarily it would go through
  # the stack to choose a layout in a somewhat confusing way.
  layout 'chf'

  # These before_filters apply the hydra access controls
  before_action :enforce_show_permissions, only: :show

  def self.uploaded_field
    solr_name('system_create', :stored_sortable, type: :date)
  end

  def self.modified_field
    solr_name('system_modified', :stored_sortable, type: :date)
  end

  def self.chf_search_fields
    [
      "#{solr_name("title", :stored_searchable)}^1000",
      "#{solr_name("additional_title", :stored_searchable)}^1000",

      "#{solr_name("after", :stored_searchable)}^500",
      "#{solr_name("artist", :stored_searchable)}^500",
      "#{solr_name("author", :stored_searchable)}^500",
      "#{solr_name("addressee", :stored_searchable)}^500",
      "#{solr_name("creator_of_work", :stored_searchable)}^500",
      "#{solr_name("contributor", :stored_searchable)}^500",
      "#{solr_name("engraver", :stored_searchable)}^500",
      "#{solr_name("interviewee", :stored_searchable)}^500",
      "#{solr_name("interviewer", :stored_searchable)}^500",
      "#{solr_name("manner_of", :stored_searchable)}^500",
      "#{solr_name("manufacturer", :stored_searchable)}^500",
      "#{solr_name("photographer", :stored_searchable)}^500",
      "#{solr_name("printer_of_plates", :stored_searchable)}^500",
      "#{solr_name("printer", :stored_searchable)}^500",
      "#{solr_name("publisher", :stored_searchable)}^500",
      "#{solr_name("genre_string", :stored_searchable)}^500",

      "#{solr_name("subject", :stored_searchable)}^100",

      "#{solr_name("description", :stored_searchable)}^50",

      solr_name("depositor"),
      solr_name("language", :stored_searchable),
      solr_name("identifier", :stored_searchable),
      solr_name("related_url", :stored_searchable),
      solr_name("place_of_interview", :stored_searchable),
      solr_name("place_of_manufacture", :stored_searchable),
      solr_name("place_of_publication", :stored_searchable),
      solr_name("place_of_creation", :stored_searchable),
      solr_name("admin_note", :stored_searchable),
      solr_name("division", :stored_searchable),
      solr_name("file_creator", :stored_searchable),
      solr_name("medium", :stored_searchable),
      solr_name("physical_container", :stored_searchable),
      solr_name("resource_type", :stored_searchable),
      solr_name("rights", :stored_searchable),
      solr_name("rights_holder", :stored_searchable),
      solr_name("series_arrangement", :stored_searchable),
      solr_name("inscription", :stored_searchable),
      solr_name("additional_credit", :stored_searchable),
      solr_name("exhibition", :stored_searchable),
      solr_name("source", :stored_searchable),
      solr_name('rights_label', :searchable)
    ]
  end

  configure_blacklight do |config|
    # Turning this off to prevent Solr stack overflows
    # see https://github.com/projectblacklight/blacklight/wiki/Blacklight-Autocomplete
    config.autocomplete_enabled = false

    config.view.gallery.partials = [:index_header, :index]
    config.view.masonry.partials = [:index]
    config.view.slideshow.partials = [:index]

    config.show.tile_source_field = :content_metadata_image_iiif_info_ssm
    config.show.partials.insert(1, :openseadragon)

    config.search_builder_class = Sufia::SearchBuilder

    # Show gallery view
    config.view.gallery.partials = [:index_header, :index]
    config.view.slideshow.partials = [:index]

    config.default_per_page = 25

    ## Default parameters to send to solr for all search-like requests. See also SolrHelper#solr_search_params
    config.default_solr_params = {
      qt: "search",
      rows: 25,
      qf: "#{chf_search_fields.join(" ")} file_format_tesim all_text_timv",
    }

    # solr field configuration for document/show views
    config.index.title_field = solr_name("title", :stored_searchable)
    config.index.display_type_field = solr_name("has_model", :symbol)
    config.index.thumbnail_field = 'thumbnail_path_ss'

    # solr fields that will be treated as facets by the blacklight application
    #   The ordering of the field names is the order of the display
    config.add_facet_field solr_name('year_facet', type: :integer), label: "Date", range: true
    config.add_facet_field solr_name("subject", :facetable), label: "Subject", limit: 5
    config.add_facet_field solr_name("maker_facet", :facetable), label: "Creator", limit: 5
    config.add_facet_field solr_name("genre_string", :facetable), label: "Genre", limit: 5
    config.add_facet_field solr_name("resource_type", :facetable), label: "Format", limit: 5
    config.add_facet_field solr_name("medium", :facetable), label: "Medium (Staff-only)", limit: 5, show: :current_user
    config.add_facet_field solr_name('place_facet', :facetable), label: "Place", limit: 5
    # only show medium facet if we have a current_user -- show takes a controller method symbol
    config.add_facet_field solr_name("language", :facetable), label: "Language", limit: 5
    config.add_facet_field solr_name("rights", :facetable), helper_method: :license_label, label: "Rights", limit: 5
    config.add_facet_field solr_name("division", :facetable), label: "Department", limit: 5
    config.add_facet_field solr_name("exhibition", :facetable), label: "Exhibition", limit: 5
    config.add_facet_field "visibility_ssi", label: "Visibility (Staff-only)", show: :current_user, helper_method: :visibility_facet_labels

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.add_facet_fields_to_solr_request!

    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display
    config.add_index_field solr_name("title", :stored_searchable), label: "Title", itemprop: 'name', if: false
    config.add_index_field solr_name("artist", :stored_searchable), label: "Artist", itemprop: 'artist', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("author", :stored_searchable), label: "Author", itemprop: 'author', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("addressee", :stored_searchable), label: "Addressee", itemprop: 'subject', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("creator_of_work", :stored_searchable), label: "Creator", itemprop: 'creator', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("engraver", :stored_searchable), label: "Engraver", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("interviewee", :stored_searchable), label: "Interviewee", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("interviewer", :stored_searchable), label: "Interviewer", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("manner_of", :stored_searchable), label: "In the manner of", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("manufacturer", :stored_searchable), label: "Manufacturer", itemprop: 'manufacturer', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("photographer", :stored_searchable), label: "Photographer", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("contributor", :stored_searchable), label: "Contributor", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("after", :stored_searchable), label: "After", itemprop: 'about', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("printer", :stored_searchable), label: "Printer", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("printer_of_plates", :stored_searchable), label: "Printer of plates", itemprop: 'contributor', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("publisher", :stored_searchable), label: "Publisher", itemprop: 'publisher', link_to_search: solr_name("maker_facet", :facetable)
    config.add_index_field solr_name("subject", :stored_searchable), label: "Subject", itemprop: 'about', link_to_search: solr_name("subject", :facetable)
    # These are marked false so they don't show up in the automatic list, but we
    # still use them to manually place on our search results screen
    config.add_index_field solr_name('date_of_work', :stored_searchable), label: "Date", itemprop: 'date_created', if: false
    config.add_index_field solr_name("genre_string", :stored_searchable), label: "Genre", itemprop: 'genre', link_to_search: solr_name("genre_string", :facetable), if: false
    config.add_index_field solr_name("description", :stored_searchable), label: "Description", itemprop: 'description', helper_method: :format_description_for_index, if: false
    config.add_index_field solr_name("additional_title", :stored_searchable), label: "Additional Title", itemprop: 'alternateName', if: false # if: :present?,





    # "fielded" search configuration. Used by pulldown among other places.
    # For supported keys in hash, see rdoc for Blacklight::SearchFields
    #
    # Search fields will inherit the :qt solr request handler from
    # config[:default_solr_parameters], OR can specify a different one
    # with a :qt key/value. Below examples inherit, except for subject
    # that specifies the same :qt as default for our own internal
    # testing purposes.
    #
    # The :key is what will be used to identify this BL search field internally,
    # as well as in URLs -- so changing it after deployment may break bookmarked
    # urls.  A display label will be automatically calculated from the :key,
    # or can be specified manually to be different.
    #
    # This one uses all the defaults set by the solr request handler. Which
    # solr request handler? The one set in config[:default_solr_parameters][:qt],
    # since we aren't specifying it otherwise.
    config.add_search_field('all_fields', label: 'All Fields') do |field|
      all_names = chf_search_fields.join(" ")
      field.solr_parameters = {
        qf: "#{all_names} file_format_tesim all_text_timv",
        pf: "#{all_names}"
      }
    end

    # "sort results by" select (pulldown)
    # label in pulldown is followed by the name of the SOLR field to sort by and
    # whether the sort is ascending or descending (it must be asc or desc
    # except in the relevancy case).
    # label is key, solr field is value
    config.add_sort_field "score desc, #{uploaded_field} desc", label: "best match"
    config.add_sort_field "latest_year desc", label: "newest date"
    config.add_sort_field "earliest_year asc", label: "oldest date"
    config.add_sort_field "#{uploaded_field} desc", label: "recently added", blank_query_default: true # will be used by our custom code as default sort when no query has been entered
    config.add_sort_field "#{uploaded_field} asc", label: "oldest added", if: ->(controller, field) { controller.current_ability.current_user.staff? }
    config.add_sort_field "#{modified_field} desc", label: "date modified \u25BC", if: ->(controller, field) { controller.current_ability.current_user.staff? }
    config.add_sort_field "#{modified_field} asc", label: "date modified \u25B2", if: ->(controller, field) { controller.current_ability.current_user.staff? }

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5

    # We don't want per-page choosing widget, nobody uses it
    config.index.collection_actions.delete(:per_page_widget)


    # We aren't currently providing alternate search results view types, we'd
    # have style others well if we wanted them. By removing all but the default,
    # the view type selection is automatically removed, and query param is ignored
    # (ie, forced to the one left)
    config.view.delete_if { |v| v != :list}
    # config.view.delete(:masonry)
    # config.view.delete(:slideshow)
    # config.view.delete(:gallery)
    # config.view[:gallery][:partials] = ["custom"]
  end

  # disable the bookmark control from displaying in gallery view
  # Sufia doesn't show any of the default controls on the list view, so
  # this method is not called in that context.
  def render_bookmarks_control?
    false
  end

  def index
    super
    @parent_presenter_lookup = parent_lookup_hash(@document_list)
  end
end
