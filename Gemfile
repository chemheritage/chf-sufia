source 'https://rubygems.org'

# sufia stuff!
gem 'sufia', '7.3.0'
gem 'blacklight_range_limit', ">= 6.1.2"
gem 'riiif', '~> 1.4'
# It may seem like this is a dependency upstream, but we need it here.
# https://project-hydra.slackarchive.io/dev/page-100/ts-1491587437169731
gem 'rsolr', '~> 1.0'
gem 'active-fedora', '~>11.1.6'
gem 'curation_concerns', '~>1.7.7'

# pull in fix to "add another" label
# Once we have a release including this commit, we can stop using this github sha:
# https://github.com/projecthydra/hydra-editor/pull/126
gem 'hydra-editor', github: 'projecthydra/hydra-editor', ref: 'c1e9d298'

# 1.3 broke OpacRecordService; lock for now
gem 'oauth2', '1.2.0'

# used in some rake tasks, some of which we may want ot run on production.
gem 'ruby-progressbar', '~> 1.0'

gem 'tty-command'

gem 'html_aware_truncation', '~> 1.0'

# extras
gem 'hydra-role-management'
gem 'highline'
gem 'rest-client'
gem 'whenever'
gem 'addressable', '~> 2.5'

gem 'rails', '~> 4.2.7.1'
gem 'devise'
gem 'devise-guests', '~> 0.3'
gem 'resque-pool'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 5.0'
# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'
# Use CoffeeScript for .coffee assets and views
gem 'coffee-rails', '~> 4.1.0'

# Use jquery as the JavaScript library
gem 'jquery-rails'
# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
#gem 'turbolinks'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'
# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0', group: :doc

gem 'openseadragon'

gem 'honeybadger', '~> 3.1'

# for our derivatives on s3
gem 'aws-sdk-s3', '~> 1.0'
gem 'concurrent-ruby', "~> 1.0"

# slack notifications on capistrano deploys
gem 'slackistrano', "~> 3.8"

source 'https://rails-assets.org' do
  gem 'rails-assets-lazysizes'
end

group :production do
  gem 'pg'
  gem 'therubyracer', platforms: :ruby
end

group :development do
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
  gem 'solr_wrapper', '>= 0.3'
end

group :development, :test do
  gem 'fcrepo_wrapper'
end
