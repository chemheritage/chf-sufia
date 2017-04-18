require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chufia
  class Application < Rails::Application

    # The compile method (default in tinymce-rails 4.5.2) doesn't work when also
    # using tinymce-rails-imageupload, so revert to the :copy method
    # https://github.com/spohlenz/tinymce-rails/issues/183
    config.tinymce.install = :copy

    # On travis, we need to provide some secret key base default value
    # so the app will load. Does not actually need to be secure for any
    # reason.
    if Rails.env.test?
      secrets.secret_key_base ||= "test_dummy"
    end

    config.autoload_paths << "#{Rails.root}/app/forms/concerns"
    # Load files from lib/
    config.autoload_paths << Rails.root.join('lib')

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end

    config.fedora_sufia6_user = "fedoraAdmin"
    config.fedora_sufia6_password = "fedoraAdmin"

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    #### WARNING: changes may necessitate data migration!!
    # model configuration
    config.makers = [
      :after,
      :artist,
      :author,
      :addressee,
      :creator_of_work,
      :contributor,
      :engraver,
      :interviewee,
      :interviewer,
      :manufacturer,
      :photographer,
      :printer_of_plates,
      :publisher,
    ]
    config.places = [
      :place_of_interview,
      :place_of_manufacture,
      :place_of_publication,
      :place_of_creation,
    ]

    # form field configuration
    config.credit_names = [
      'Douglas Lockard',
      'Gregory Tobias',
      'Mark Backrath',
      'Penn School of Medicine',
      'Will Brown',
    ]

    config.credit_roles = {
      'photographer' => 'Photographed by',
    }

    config.divisions = [
      'Archives',
      'Center for Oral History',
      'Museum',
      'Library',
    ]

    config.file_creators = [
      'Brown, Will',
      'DiMeo, Michelle',
      'George Blood Audio LP',
      'Kativa, Hillary',
      'Lockard, Douglas',
      'Lu, Cathleen',
      'Miller, Megan',
      'Muhlin, Jay',
      'Newhouse, Sarah',
      'The University of Pennsylvania Libraries',
      'Tobias, Gregory',
      'Voelkel, James',
    ]

    config.external_ids_hash = {
      'object' => 'Object ID',
      'bib' => 'Sierra Bib. No.',
      'item' => 'Sierra Item No.',
      'accn' => 'Accession No.',
      'aspace' => 'ASpace Reference No.',
      'interview' => 'Oral History Interview No.',
    }

    config.genres = [
      'Advertisements',
      'Artifacts',
      'Business correspondence',
      'Catalogs',
      'Chemistry sets',
      'Clothing & dress',
      'Diagrams',
      'Documents',
      'Drawings',
      'Encyclopedias and dictionaries',
      'Electronics',
      'Engravings',
      'Ephemera',
      'Etchings',
      'Glassware',
      'Handbooks and manuals',
      'Illustrations',
      'Implements, utensils, etc.',
      'Lithographs',
      'Manuscripts',
      'Minutes (Records)',
      'Molecular models',
      'Negatives',
      'Oral histories',
      'Paintings',
      'Pamphlets',
      'Personal correspondence',
      'Photographs',
      'Plastics',
      'Portraits',
      'Postage stamps',
      'Press releases',
      'Prints',
      'Rare books',
      'Sample books',
      'Scientific apparatus and instruments',
      'Slides',
      'Stereographs',
      'Textiles',
      'Vessels (Containers)'
    ]

    config.physical_container_fields = {
      'b'=>'box', 'f'=>'folder', 'v'=>'volume', 'p'=>'part', 'g'=>'page'
    }


    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Do not swallow errors in after_commit/after_rollback callbacks.
    config.active_record.raise_in_transactional_callbacks = true

    # Active job should use resque
    config.active_job.queue_adapter = :resque
  end
end
