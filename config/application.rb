require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chufia
  class Application < Rails::Application

    # Due to a bug in honeybadger, the at_exit callback isn't being installed, cause
    # honeybadger thinks we're sinatra, so error reports can be lost at app shutdown --
    # and in the special case of rake task, usually will be.
    # We do this manually. If honeybadger fixes it's thing, this might result
    # in double callback, which theoretically isn't great.
    # https://github.com/honeybadger-io/honeybadger-ruby/issues/258
    Honeybadger.install_at_exit_callback

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

    #config.autoload_paths << "#{Rails.root}/app/forms/concerns"

    # Autoload files from lib/. This was probably not a great idea, things
    # should just be in app/ if you want them autoloaded.
    config.autoload_paths << Rails.root.join('lib')
    config.eager_load_paths << Rails.root.join('lib')

    # Load all subdirs of './patches'
    config.autoload_paths.concat Dir.glob(Rails.root.join("patches/*"))
    config.eager_load_paths.concat Dir.glob(Rails.root.join("patches/*"))

    # load overrides
    config.to_prepare do
      Dir.glob(Rails.root.join("app/**/*_override*.rb")) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.generators do |g|
      g.test_framework :rspec, :spec => true
    end

    config.fedora_sufia6_user = "fedoraAdmin"
    config.fedora_sufia6_password = "fedoraAdmin"

    if ENV["LOG_LEVEL"].present?
      config.log_level = ENV["LOG_LEVEL"].to_s
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    #### WARNING: changes may necessitate data migration!!
    # model configuration
    config.makers = [
      :after,
      :artist,
      :attributed_to,
      :author,
      :addressee,
      :creator_of_work,
      :contributor,
      :editor,
      :engraver,
      :interviewee,
      :interviewer,
      :manufacturer,
      :manner_of,
      :photographer,
      :printer,
      :printer_of_plates,
      :publisher,
      :school_of,
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

    config.projects = [
      'Atmospheric Science',
      'Chemical History of Electronics',
      "Imagining Philadelphia's Energy Futures",
      'Mass Spectrometry',
      'Nanotechnology',
      'Oral History of the Toxic Substances Control Act',
      'Pew Biomedical Scholars',
      'REACH Ambler',
      'Scientific and Technical Information Systems',
      'Science and Disability',
    ]

    config.file_creators = [
      'Brown, Will',
      'Center for Oral History',
      'Conservation Center for Art & Historic Artifacts',
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
      'Charts, diagrams, etc',
      'Chemistry sets',
      'Clothing & dress',
      'Documents',
      'Drawings',
      'Encyclopedias and dictionaries',
      'Electronics',
      'Engravings',
      'Ephemera',
      'Etchings',
      'Figurines',
      'Glassware',
      'Handbooks and manuals',
      'Illustrations',
      'Implements, utensils, etc.',
      'Lithographs',
      'Manuscripts',
      'Medical equipment & supplies',
      'Minutes (Records)',
      'Molecular models',
      'Money (Objects)',
      'Negatives',
      'Oral histories',
      'Paintings',
      'Pamphlets',
      'Personal correspondence',
      'Pesticides',
      'Photographs',
      'Photomechanical prints',
      'Plastics',
      'Portraits',
      'Postage stamps',
      'Press releases',
      'Prints',
      'Publications',
      'Rare books',
      'Sample books',
      'Scientific apparatus and instruments',
      'Slides',
      'Stereographs',
      'Textiles',
      'Vessels (Containers)',
      'Woodcuts'
    ]

    config.exhibitions = [
      "Age of Alchemy",
      "Books of Secrets",
      "Elemental Matters",
      "ExhibitLab",
      "Inspiring Youth in Chemistry",
      "Lobby 2017",
      "Making Modernity",
      "Marvels and Ciphers",
      "Molecules That Matter",
      "Object Explorer",
      "Science at Play",
      "Second Skin",
      "Sensing Change",
      "The Alchemical Quest",
      "The Sky's the Limit",
      "The Whole of Nature and the Mirror of Art",
      "Things Fall Apart",
      "Transmutations"
    ]

    config.physical_container_fields = {
      'b'=>'box', 'f'=>'folder', 'v'=>'volume', 'p'=>'part', 'g'=>'page', 's' => 'shelfmark'
    }

    # Organizational social media accounts/handles
    config.twitter_acct = "scihistoryorg"
    config.facebook_acct = "SciHistoryOrg"
    config.instagram_acct = "scihistoryorg"

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Active job should use resque
    config.active_job.queue_adapter = :resque

    # Show the GDPR "I accept" cookies banner by default.
    # This setting is overridden in test.rb,
    # so the tests don't have to click "I accept".)
    config.hide_accept_cookies_banner = false

    def log_error(error)
      Honeybadger.notify(error)
    end
  end
end
