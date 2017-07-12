# config valid only for current version of Capistrano
lock '3.8.1'

set :application, 'chf-sufia'
set :repo_url, 'https://github.com/chemheritage/chf-sufia.git'
#set :branch, 'master'
set :deploy_to, '/opt/sufia-project'
set :log_level, :info
set :keep_releases, 5
# label deploys with server local time instead of utm
set :deploytag_utc, false

# use 'passenger-config restart-app' to restart passenger
set :passenger_restart_with_touch, false

# send some data to whenever
set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }
set :whenever_roles, [:app, :jobs]

# not all machines should run bundler; some won't have ruby
set :bundle_roles, [:app, :jobs]

# Prompt which branch to deploy; default to current.
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
set :linked_files, fetch(:linked_files, []).push('config/initializers/devise.rb', 'config/blacklight.yml', 'config/database.yml', 'config/fedora.yml', 'config/redis.yml', 'config/resque-pool.yml', 'config/secrets.yml', 'config/solr.yml', 'config/local_env.yml')
# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system')
# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end

namespace :chf do
  # Restart resque-pool.
  desc "Restart resque-pool"
  task :resquepoolrestart do
    on roles(:jobs) do
      execute :sudo, "/usr/sbin/service resque-pool restart"
    end
  end
  after "deploy:symlink:release", "chf:resquepoolrestart"

  # load the workflow configs
  desc "Load workflow configurations"
  task :loadworkflows do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'curation_concerns:workflow:load'
        end
      end
    end
  end
  after "deploy:symlink:release", "chf:loadworkflows"

  # create default admin set (note this only needs to run
  # once on any given install, but is idempotent)
  desc "create default admin set"
  task :create_default_admin_set do
    on roles(:app) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'sufia:default_admin_set:create'
        end
      end
    end
  end
  after "chf:loadworkflows", "chf:create_default_admin_set"

  desc "add solr_restart=true to your cap invocation (e.g. on first solr deploy), otherwise it will reload config files"
  task :restart_or_reload_solr do
    on roles(:solr) do
      if ENV['solr_restart'].eql? "true"
        execute :sudo, "/usr/sbin/service solr restart"
      else
        # the querystring doesn't come through without the quotes
        execute :curl, '"localhost:8983/solr/admin/cores?action=reload&core=collection1"'
      end
    end
  end
  after "deploy:log_revision", "chf:restart_or_reload_solr"
end
