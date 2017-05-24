require 'resque/server'

Rails.application.routes.draw do
  concern :range_searchable, BlacklightRangeLimit::Routes::RangeSearchable.new
  Hydra::BatchEdit.add_routes(self)
  mount Qa::Engine => '/authorities'

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
  resources :welcome, only: 'index'
  root 'frontpage#index'
  curation_concerns_collections
  curation_concerns_basic_routes
  curation_concerns_embargo_management
  concern :exportable, Blacklight::Routes::Exportable.new

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
