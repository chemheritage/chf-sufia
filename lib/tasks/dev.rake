# Some of these tasks require rspec which isn't avail in production, so
# so avoid loading all these dev: tasks in production.
unless ENV['RAILS_ENV'] == "production"
  require 'rspec/core'
  require 'rspec/core/rake_task'
  require 'solr_wrapper'
  require 'fcrepo_wrapper'
  require 'active_fedora/rake_support'

  # This can be removed when solr_wrapper is upgraded.
  # See the patch file for more details.
  require "#{Rails.root}/lib/solr_wrapper_patch"

  namespace :dev do
    # Starts Fedora and Solr, per config in `./config/solr_wrapper_test.rb` and
    # and `./config/fcrepo_wrapper_test.rb`. You can still run individual files
    # and line numbers, with:
    #
    #    SPEC=spec/models/users_spec.rb:30 ./bin/rake chf:spec_with_app_load
    #
    # or even multiple ones.... not sure.
    #
    # Used for travis.
    # Based on similar in sufia.
    desc 'Spin up test servers and run specs'
    task :spec_with_app_load  do
      with_test_server do
        Rake::Task['spec'].invoke
      end
    end

    # Believe it or not, there was no built-in sufia stack task
    # that would spin up just fedora and solr but not rails in dev.
    # I wanted it. You can use this in dev or test, it will use
    # appropriate fcrepo_wrapper and solr_wrapper configs depending
    # on environment.
    #
    #      ./bin/rake dev:servers
    #      RAILS_ENV=test ./bin/rake dev:servers
    #
    # Note that in developemnt env config is taken from `.solr_wrapper` and
    # `.fcrepo_wrapper` but in test env, from `./config/solr_wrapper_test.yml`
    # and `./config/fcrepo_wrapper_test.yml`, cause that's hydra stack conventions
    # for some reason.
    #
    # Based on code at https://github.com/projecthydra/hydra-head/blob/b5c92ec8bee49f1788637caf23df8ab599922084/hydra-core/lib/tasks/hydra.rake#L9
    desc 'spin up fedora and solr (not rails)'
    task :servers do
      with_server(ENV['RAILS_ENV'] || 'development') do
        begin
          sleep
        rescue Interrupt
          puts "Stopping server"
        end
      end
    end

    # Creates some works. First task arg is email of account to register as
    # uploader. Second arg is password if you want the account to be created
    # too.
    #
    # ENV[NUM_PUBLIC_WORKS] number of works to create, default 5
    # ENV[NUM_PRIVATE_WORKS] number of works to create, default 1
    # ENV[NUM_FILESETS] number of filesets to create per work, default 1
    # ENV[NUM_CHILD_WORKS] number of child works to add to each work created, default 0.
    # ENV[TITLE_BASE] title to use for the works, will have an integer appended
    #
    #    BASE_TITLE="Lots of files" NUM_PUBLIC_WORKS=1 NUM_PRIVATE_WORKS=0 NUM_FILESETS=200 bundle exec rake dev:data[jrochkind@chemheritage.org]
    desc 'create some sample data for dev'
    task :data, [:email, :password] => :environment do |t, args|
      other_keyword_args = {}

      num_public_works =(ENV['NUM_PUBLIC_WORKS'] || 5).to_i
      num_private_works = (ENV['NUM_PRIVATE_WORKS'] || 5).to_i
      num_child_works = (ENV['NUM_CHILD_WORKS'] || 0).to_i
      work_base_title = ENV['TITLE_BASE'].presence || "Dev Public Work"

      if args[:email]
        user = User.find_by_email(args[:email]) || User.create!(email: args[:email], password: args[:password])
        other_keyword_args[:user] = user
      end

      num_public_works.times do |i|
        FactoryGirl.create(:full_public_work,
            num_images: (ENV['NUM_FILESETS'] || 1).to_i,
            title: ["#{work_base_title}_#{i +1}"],
            **other_keyword_args).tap do |w|

          num_child_works.times do |i|
            w.ordered_members << FactoryGirl.create(:full_public_work, num_images: 1, title: ["#{work_base_title}_CHILD_#{i +1}"])
          end
          w.save

          $stderr.puts "created public work: #{w.id}"
        end
      end
      num_private_works.times do |i|
        FactoryGirl.create(:private_work, :with_complete_metadata, :real_public_image,
            num_images: (ENV['NUM_FILESETS'] || 1).to_i,
            title: ["#{(ENV['BASE_TITLE'] || "Dev Private Work")}_#{i +1}"],
            **other_keyword_args).tap do |w|

          num_child_works.times do |i|
            w.ordered_members << FactoryGirl.create(:private_work, num_images: 1, title: ["#{(ENV['BASE_TITLE'] || "Dev Public Work")}_CHILD_#{i +1}"])
          end
          w.save

          $stderr.puts "created private work: #{w.id}"
        end
      end
    end

    require 'active_fedora/cleaner'
    # for hyrax see also https://github.com/RepoCamp/ahc/blob/master/tasks/dev.rake
    namespace :clear do
      desc "clear all data out of solr"
      task :solr => :environment do
        raise "For safety can't do this on production" if Rails.env.production?
        ActiveFedora::SolrService.instance.conn.delete_by_query("*:*")
        ActiveFedora::SolrService.instance.conn.commit
      end

      desc "clear all data out of fedora"
      task :fedora => :environment do
        raise "For safety can't do this on production" if Rails.env.production?
        ActiveFedora::Cleaner.clean!
      end

      desc "clear temporary and derivative files"
      task :derivatives => :environment do
        raise "For safety can't do this on production" if Rails.env.production?
        # legacy derivatives location, probably empty since we aren't using
        # anymore.
        FileUtils.rm_rf(Sufia.config.derivatives_path)
        FileUtils.mkdir_p(Sufia.config.derivatives_path)

        # S3 derivatives
        if CHF::Env.lookup('derivative_s3_bucket') && CHF::Env.lookup('aws_access_key_id') && CHF::Env.lookup('aws_secret_access_key')
          CHF::CreateDerivativesOnS3Service.s3_bucket!.clear!
        end
      end

      desc "clear redis"
      task :redis do
        raise "For safety can't do this on production" if Rails.env.production?
        Redis.current.keys.map { |key| Redis.current.del(key) }
      end

      # You may want to follow up with:
      # rake chf:user:test:create[somebody@chemheritage.org,password] chf:admin:grant[somebody@chemheritage.org]
      desc "Reset db, solr, fedora, some caches, and proper setup for blank slate"
      task :all => [:solr, :fedora, :derivatives, :redis, "db:reset"]  do
        Rake::Task['curation_concerns:workflow:load'].invoke
        Rake::Task['sufia:default_admin_set:create'].invoke
      end
    end
  end
end


