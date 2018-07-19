require 'resque/server'

Rails.application.routes.draw do
  default_url_options host: CHF::Env.lookup(:app_hostname)

  concern :oai_provider, BlacklightOaiProvider::Routes.new


  # Override a path from BrowseEverything engine, to
  # fix: https://github.com/samvera/browse-everything/commit/6416ce9d611a3f24d9684916edc0484e737c34d9
  # If we are using a version of BrowseEverything in the future containing this commit, this patch
  # will be unneccesary.
  #
  # We have to put it FIRST in routes to 'override', and then also use a constraint to avoid
  # taking over the b-e routes that are supposed to come first. :(
  scope format: false, constraints: { provider: %r{(?!(resolve|connect)/?)[^/]+} } do
    match '/browse/:provider(/*path)', to: 'browse_everything#show', via: [:get, :post]
  end
  mount BrowseEverything::Engine => '/browse'


  # this will fall through to ./views/application/robots.txt.erb, no need for an action method
  get 'robots.txt', to: "application#robots.txt", format: "text"

  # override sufia's about routing to use a static page instead of a content block
  get 'about', controller: 'static', action: 'about', as: 'about'
  # add a policy page
  get 'policy', controller: 'static', action: 'policy', as: 'policy'
  # override sufia's contact routing to use a static page instead of a form
  get 'contact', controller: 'static', action: 'contact', as: 'contact'
  # add a faq page
  get 'faq', controller: 'static', action: 'faq', as: 'faq'
  # remove help page, replaced with 'faq'
  get 'help', to: proc { raise ActionController::RoutingError.new('Not Found') }

  get "force_500", controller: "application", action: "intentional_error"

  # On-demand derivatives
  get "works/:id/pdf", to: "on_demand_derivatives#pdf", as: :on_demand_pdf
  get "works/:id/zip", to: "on_demand_derivatives#zip", as: :on_demand_zip

  # remove weird zotero and mendeley pages with weird message, so it doesn't get
  # google indexed.
  get "zotero", to: proc { raise ActionController::RoutingError.new('Not Found') }
  get "mendeley", to: proc { raise ActionController::RoutingError.new('Not Found') }

  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  Hydra::BatchEdit.add_routes(self)
  mount Qa::Engine => '/authorities'

  # Administrative URLs
  namespace :admin do
    # Job monitoring
    constraints ResqueAdmin do
      mount Resque::Server, at: 'queues'
    end
    # Fixity check
    resources :fixity, only: [:index]
  end

  mount Blacklight::Engine => '/'

    concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    #concerns :oai_provider

    concerns :searchable
    concerns :range_searchable

  end

  # Gives us a top-level "/oai" path, that routes to OaiPmhController#oai, our custom
  # controller that sub-classes CatalogController, that we've added blacklight_oai_provider
  # functionality to. This is a bit different than default blacklight_oai_provider, in part
  # because it was one way we found to limit results to just genericworks in oai-pmh.
  scope controller: "oai_pmh", as: "oai_pmh" do
    concerns :oai_provider
  end

  devise_for :users
  # https://github.com/plataformatec/devise/wiki/how-to:-change-the-default-sign_in-and-sign_out-routes
  devise_scope :user do
    get 'login', to: 'devise/sessions#new'
  end

  resources :welcome, only: 'index'
  root 'sufia/homepage#index'


  # Redirect from OLD work URLs to the new ones that we will install/override below.
  # Also we are getting rid of the `parent` URLs.
  get '/concern/generic_works/:id', to: redirect('/works/%{id}')
  get '/concern/generic_works/:id/viewer/:filesetid', to:  redirect('/works/%{id}/viewer/%{filesetid}')
  get '/concern/parent/:parent_id/generic_works/:id', to: redirect('/works/%{id}')
  get '/concern/parent/:parent_id/generic_works/:id/viewer/:filesetid', to: redirect('/works/%{id}/viewer/%{filesetid}')


  # Override collections/$id to point to our new custom controller
  get "collections/:id" => "collections_show#index", constraints: lambda { |req| req.params[:id] != "new" }
  get "collections/:id/range_limit" => "collections_show#range_limit"
  get "collections/:id/facet" => "collections_show#facet"
  get "focus/:id/range_limit" => "synthetic_category#range_limit"
  get "focus/:id/facet" => "synthetic_category#facet"


  curation_concerns_collections
  curation_concerns_basic_routes
  curation_concerns_embargo_management
  concern :exportable, Blacklight::Routes::Exportable.new


  #############
  #
  #  CHF crazy code to remove named route installed by sufia/CC, and install same named route
  #  with different URL. This is indeed confusing and weird, messing with trying to override
  #  already defined Rails resourceful routes and named helpers, which rails doesn't really want
  #  you to do.
  #
  ##############

    # Rails private API to _uninstall_ named route, may break in future
    Rails.application.routes.named_routes.send(:routes).delete(:curation_concerns_generic_work)
    Rails.application.routes.named_routes.send(:routes).delete(:curation_concerns_parent_generic_work)

    # Have to recreate the routes, such that they are at /works, not breaking any use of
    # curation_concerns_generic_work_path helper method.
    namespace :curation_concerns, path: '' do
      resources "generic_works", path: '/works', except: [:index]
    end

    # We want to GET RID of the `/concern/parent` urls, and just use standard /work urls.
    # This is a trick to create the `curation_concerns_parent_generic_work` route helper methods
    # sufia/CC use, to point to ur new desired /work URL. It depends on us having used private
    # Rails API to remove the previosu named route above.
    get "/works/:id", to: "curation_concerns/generic_works#show", params: {parent_id: nil}, as: "curation_concerns_parent_generic_work"


  # there might be a way to get curation_concerns routes to this for us,
  # but don't know it, and this is easy enough and works. Make the viewer
  # URL lead to ordinary show page, so JS can pick it up and launch viewer.
  get '/works/:id/viewer/:filesetid(.:format)' => 'curation_concerns/generic_works#show', as: :viewer
  get '/parent/:parent_id/works/:id/viewer/:filesetid(.:format)' => 'curation_concerns/generic_works#show'
  # our viewer json route
  get '/works/:id/viewer_images_info' => 'curation_concerns/generic_works#viewer_images_info', defaults: {format: "json"}, format: false, as: :viewer_images_info

  # redirect to signed s3
  get '/download_redirect/:id/:filename_key' => "downloads#s3_download_redirect", as: :s3_download_redirect

  post '/concern/parent/:parentid/file_sets/:filesetid/to_child_work' => 'member_conversion#to_child_work', as: :to_child_work
  post '/works/parent/:parentworkid/child/:childworkid/to_fileset'    => 'member_conversion#to_fileset', as: :to_fileset

  resources :solr_documents, only: [:show], path: '/catalog', controller: 'catalog' do
    concerns :exportable
  end

  resources :bookmarks do
    concerns :exportable

    collection do
      delete 'clear'
    end
  end

  # local routes
  get '/opac_data/:rec_num', to: 'opac_data#load_bib'
  mount Hydra::RoleManagement::Engine => '/'

  get '/focus/:id', to: 'synthetic_category#index', as: :synthetic_category


  Hydra::BatchEdit.add_routes(self)
  # Sufia should be mounted before curation concerns to give priority to its routes
  mount Sufia::Engine => '/'
  mount CurationConcerns::Engine, at: '/'

end
