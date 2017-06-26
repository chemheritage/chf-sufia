require 'resque/server'

Rails.application.routes.draw do
  # override sufia's about routing to use a static page instead of a content block
  get 'about', controller: 'static', action: 'about', as: 'about'

  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  Hydra::BatchEdit.add_routes(self)
  mount Qa::Engine => '/authorities'
  mount Riiif::Engine => '/image-service', as: 'riiif'

  # Administrative URLs
  namespace :admin do
    # Job monitoring
    constraints ResqueAdmin do
      mount Resque::Server, at: 'queues'
    end
  end

  mount Blacklight::Engine => '/'

    concern :searchable, Blacklight::Routes::Searchable.new

  resource :catalog, only: [:index], as: 'catalog', path: '/catalog', controller: 'catalog' do
    concerns :searchable
    concerns :range_searchable

  end

  devise_for :users
  # https://github.com/plataformatec/devise/wiki/how-to:-change-the-default-sign_in-and-sign_out-routes
  devise_scope :user do
    get 'login', to: 'devise/sessions#new'
  end

  # make the contact form inaccessible since we're using mailto
  get 'contact', to: redirect('/404')

  resources :welcome, only: 'index'
  root 'sufia/homepage#index'
  curation_concerns_collections
  curation_concerns_basic_routes
  curation_concerns_embargo_management
  concern :exportable, Blacklight::Routes::Exportable.new

  # there might be a way to get curation_concerns routes to this for us,
  # but don't know it, and this is easy enough and works. Make the viewer
  # URL lead to ordinary show page, so JS can pick it up and launch viewer.
  get '/concern/generic_works/:id/viewer/:filesetid(.:format)' => 'curation_concerns/generic_works#show'
  get '/concern/parent/:parent_id/generic_works/:id/viewer/:filesetid(.:format)' => 'curation_concerns/generic_works#show'


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

  get '/focus/:id', to: 'synthetic_category#show', as: :synthetic_category


  Hydra::BatchEdit.add_routes(self)
  # Sufia should be mounted before curation concerns to give priority to its routes
  mount Sufia::Engine => '/'
  mount CurationConcerns::Engine, at: '/'
end
