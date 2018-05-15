source 'https://rubygems.org'

# sufia stuff!
gem 'sufia', '7.4.0'
gem 'blacklight_range_limit', ">= 6.1.2"

# While sufia theoretically allows rsolr 2.x, we have found problems with it:
# "a bug where submitting a record edit form did not correctly load the redirect back to the
# show page." So have locked to 1.x. Some info was at:
# https://project-hydra.slackarchive.io/dev/page-100/ts-1491587437169731
# Update: slackarchive permalink doesn't work after some max. search for 'rsolr' and look
# at April 7 results for hints of the conversation? Unfortunately you can't get context.
gem 'rsolr', '~> 1.0'
gem 'active-fedora', '~>11.1.6'
gem 'curation_concerns', '~>1.7.7'

# pull in fix to "add another" label
# Once we have a release including this commit, we can stop using this github sha:
# https://github.com/projecthydra/hydra-editor/pull/126
# Requires hydra-editor >= 3.2.0, but that reqiures almond-rails >= 0.1, and
# sufia insists on almond-rails 0.1.x. :(
gem 'hydra-editor', git: 'https://github.com/projecthydra/hydra-editor', ref: 'c1e9d298'

# 1.3 broke OpacRecordService; lock for now
gem 'oauth2', '1.2.0'

# OAI PMH for DPLA export
gem 'blacklight_oai_provider'

# used in some rake tasks, some of which we may want ot run on production.
gem 'ruby-progressbar', '~> 1.0'

gem 'tty-command'

gem 'html_aware_truncation', '~> 1.0'

gem 'sitemap_generator', '~> 6.0'

# extras
gem 'hydra-role-management'
gem 'highline'
gem 'rest-client'
gem 'whenever'
gem 'addressable', '~> 2.5'

# we use for data structures for citation models, and for generating citations
gem "citeproc-ruby", '~> 1.0'
gem 'csl-styles', '~> 1.0' # Need to load the styles so we can use chicago
# On MRI <= 2.3, citeproc-ruby insists upon `unicode` or `unicode_utils` gem. :(
# https://github.com/inukshuk/citeproc/commit/c14d3cd272698dd4aa52625dd140864b7a7bd6cb
gem 'unicode'


gem 'rails', '~> 5.0.0'
gem 'devise'
gem 'devise-guests', '~> 0.3'
gem 'resque-pool'
# used by resque admin page
gem 'sinatra', '~> 2.0'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
gem 'sass', "~> 3.4.0" # may be some backwards incompat in 3.5
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.2'

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks', '~> 5'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.5'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'openseadragon'
gem 'prawn', "~> 2.2" #PDF Maker
gem "pdf-reader", group: [:test, :development] # at the moment just used in a spec to verify PDF

gem 'honeybadger', '~> 3.1'

# for our derivatives on s3
gem 'aws-sdk-s3', '~> 1.0'
gem 'concurrent-ruby', "~> 1.0"

# slack notifications on capistrano deploys
gem 'slackistrano', "~> 3.8"

source 'https://rails-assets.org' do
  gem 'rails-assets-lazysizes'
  gem 'rails-assets-promise-polyfill' # mainly for use by fetch polyfill
  gem 'rails-assets-fetch' # fetch polyfill, initially used by our custom viewer
end

group :production do
  gem 'pg'
  gem 'therubyracer', platforms: :ruby
end

group :development do
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '~> 3.0.5'
  gem 'capistrano', '~> 3.8'
  gem 'capistrano-bundler', '~> 1.2'
  gem 'capistrano-passenger', '~> 0.2'
  gem 'capistrano-rails', '~> 1.2'
  gem 'capistrano-maintenance', '~> 1.0', require: false
end

group :development, :test, :profile do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'pry-byebug'
  gem 'sqlite3'
  # Access an IRB console on exception pages or by using <%= console %> in views
  #gem 'web-console', '~> 2.0'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'guard-rspec'
  gem 'spring-commands-rspec', '~> 1.0.2'

  gem 'rspec-rails', '~> 3.1'
  gem "factory_girl_rails", "~> 4.4", '>= 4.4.1'
  gem 'jettywrapper'
  gem 'pry'
  gem 'pry-rails'
  gem 'equivalent-xml'
  ## debugging
  #gem 'httplog'
  gem 'ruby-prof'
end

group :test do
  gem 'capybara', '~> 2.4'
  gem 'database_cleaner', '~> 1.3'
  gem 'poltergeist', '~> 1.5'
  gem 'jasmine', '~> 2.3'
  gem 'rspec-activemodel-mocks'
  gem 'webmock'
  gem 'phantomjs', '~> 2.1.1'
  gem 'capybara-screenshot'
end

group :development, :test do
  # Need to get unreleased mirror_url feature so it can download despite being blocked by apache.org on travis,
  # and our tests can pass again. a release of solr_wrapper 1.3.0 should let us go back to a released gem.
  gem 'solr_wrapper', git: 'https://github.com/cbeer/solr_wrapper', branch: 'master'
  #gem 'solr_wrapper', '>= 0.3'
end

group :development, :test do
  gem 'fcrepo_wrapper'
end
