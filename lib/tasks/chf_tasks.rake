require_dependency Rails.root.join('lib','chf','reports','metadata_completion_report')

namespace :chf do

  desc "run fixity checks with logs and notification on failure"
  task :fixity_checks => :environment do
    ::FileSet.find_each do |gf|
      Hyrax::FileSetFixityCheckService.new(gf, async_jobs: false, latest_version_only: true).fixity_check
    end
  end

  desc "re-run just failed fixity checks"
  task :rerun_failed_fixity_checks => :environment do
    rel = ChecksumAuditLog.latest_checks.where(passed: false)

    total_failed = rel.count

    $stderr.puts "Total failed latest checks: #{total_failed}"

    progress_bar = ProgressBar.create(total: total_failed)

    # Force max_days_between_fixity_checks -1, do it now no matter what!
    rel.find_each do |checksum_audit_log|
      begin
        progress_bar.increment
        Hyrax::FileSetFixityCheckService.new(checksum_audit_log.file_set_id, max_days_between_fixity_checks: -1, async_jobs: false, latest_version_only: true).fixity_check
      rescue Ldp::Gone => e
        progress_bar.log "ChecksumAuditLog=#{checksum_audit_log.id}: #{e.inspect}: FileSet apparently no longer present: #{checksum_audit_log.file_set_id}"
      end
    end

    $stderr.puts "Re-ran checks, after re-run total failed latest checks: #{rel.count}"
  end


  desc 'Rough count metadata completion'
  task metadata_report: :environment do
    report = CHF::Reports::MetadataCompletionReport.new
    report.run
    path = File.path("/var/sufia/reports/metadata/")
    FileUtils.mkdir_p(path) unless File.exists?(path)
    fn = "completion-#{Date.today.strftime('%Y-%m-%d-%T')}.txt"
    File.open(File.join(path, fn), 'w') do |f|
      f.write(report.get_output)
      f.write("\n")
    end
  end

  desc 'Re-characterize all files. Cleans up temp files as it goes. Does not generate derivatives. `RAILS_ENV=production bundle exec rake chf:recharacterize`'
  task recharacterize: :environment do
    progress_bar = ProgressBar.create(:total => Sufia.primary_work_type.count, format: "%t: |%B| %p%% %e")
    Sufia.primary_work_type.all.find_each do |work|
      work.file_sets.each do |fs|
        fs.files.each do |file|
          RecharacterizeJob.perform_now(fs, file.id)
        end
      end
      progress_bar.increment
    end
  end

  desc 'Re-generate all derivatives. WARNING: make sure you have enough space in your temp directories before running! `RAILS_ENV=production bundle exec rake chf:create_derivatives`, or also with WORK_IDS="xd07gs68,zg64tk92g,etc"'
  task create_derivatives: :environment do
    require Rails.root.join('lib','minimagick_patch')
    MiniMagick::Tool.quiet_arg = true

    condition = if ENV['WORK_IDS'].present?
      { id: ENV['WORK_IDS'].split(",") }
    else
      {}
    end

    progress_bar = ProgressBar.create(:total => Sufia.primary_work_type.where(condition).count, format: "%t: |%B| %p%% %e")

    Sufia.primary_work_type.find_each(condition) do |work|
      work.file_sets.each do |fs|
        fs.files.each do |file|
          filename = CurationConcerns::WorkingDirectory.find_or_retrieve(file.id, fs.id)
          fs.create_derivatives(filename)
        end
      end
      progress_bar.increment
    end
    MiniMagick::Tool.quiet_arg = false
  end

  desc 'Migrate titles and merge descriptions'
  task single_value_migration: :environment do
    CHF::Metadata::SingleValueMigration.run
    puts 'migration complete'
  end

  desc 'Reindex everything. `RAILS_ENV=production bundle exec rake chf:reindex`'
  task reindex: :environment do
    CHF::Indexer.new.reindex_everything(progress_bar: true, final_commit: true)
  end

  desc 'report translated titles'
  task translated: :environment do
    reporter = CHF::Metadata::TranslatedTitleUpdate.new
    reporter.run
    reporter.matches.each do |id, line|
      puts "#{id}:"
      line.each do |key, val|
        puts "  #{key}: #{val}"
      end
    end
    puts "total: #{reporter.matches.size}"
  end

  desc 'Reindex Collections. `RAILS_ENV=production bundle exec rake chf:reindex_collections`'
  task reindex_collections: :environment do
    # reindex only Collections
    # not a frequent task but useful in upgrade to sufia 7.3
    # There aren't enough of them to really need batches, etc.

    progress_bar = ProgressBar.create(:total => Collection.count, format: "%t: |%B| %p%% %e")

    Collection.find_each do |coll|
      coll.update_index
      progress_bar.increment
    end

    $stderr.puts 'reindex_collections complete'
  end

  desc 'Reindex all GenericWorks. `RAILS_ENV=production bundle exec rake chf:reindex_works`'
  task reindex_works: :environment do
    # Like :reindex, but only GenericWorks, makes it faster,
    # plus let's us use other solr techniques to make it faster,
    # and allows us to add a progress bar easily.

    add_batch_size = ENV['ADD_BATCH_SIZE'] || 50

    progress_bar = ProgressBar.create(:total => GenericWork.count, format: "%t: |%B| %p%% %e")
    solr_service_conn = ActiveFedora::SolrService.instance.conn
    batch = []

    GenericWork.find_each do |work|
      batch << work.to_solr

      if batch.count % add_batch_size == 0
        solr_service_conn.add(batch, softCommit: true, commit: false)
        batch.clear
      end
      progress_bar.increment
    end
    if batch.present?
      solr_service_conn.add(batch, softCommit: true, commit: false)
      batch.clear
    end
    $stderr.puts "Issuing a solr commit..."
    solr_service_conn.commit

    $stderr.puts 'reindex_works complete'
  end

  desc 'csv report of related_urls'
  task :related_url_csv, [:output_path] => :environment do |t, args|
    output = args[:output_path] || "related_urls.csv"
    CHF::Metadata::RelatedUrlReport.new.to_csv(output)
  end

  desc "set collection thumbnails. Assumes image is in `collections/` subdir. `RAILS_ENV=production bundle exec rake chf:collection_images[dr26xx95r=dr26xx95r_2x.jpg]`"
  task :collection_images, [:arg_str] => :environment do |t, args|
    args[:arg_str].split(',').each do |pair|
      id, path = pair.split("=")
      Collection.find(id).update!(representative_image_path: path)
    end
  end

  desc "set all collection thumbnails assuming they are named collections/[id_2x.jpg]"
  task collection_images_by_id: :environment do
    base_path = Rails.root.join('app/assets/images/collections')
    Collection.find_each do |coll|
      rel_path = "#{coll.id}_2x.jpg"
      coll.update!(representative_image_path: rel_path) if base_path.join(rel_path).exist?
    end
  end

  namespace :admin do

    desc 'Grant admin role to existing user. `RAILS_ENV=production bundle exec rake chf:admin:grant[admin@chemheritage.org]`'
    task :grant, [:email] => :environment do |t, args|
      begin
        CHF::Utils::Admin.grant(args[:email])
      rescue ActiveRecord::RecordNotFound
        abort("User #{args[:email]} does not exist. Only an existing user can be promoted to admin")
      end
      puts "User: #{args[:email]} is an admin."
    end

    desc 'Revoke admin role from user.'
    task :revoke, [:email] => :environment do |t, args|
      CHF::Utils::Admin.revoke(args[:email])
      puts "User: #{u.email} is no longer an admin."
    end

    desc 'List all admin users'
    task list: :environment do
      puts "Admin users:"
      Role.find_by(name: 'admin').users.each { |u| puts "  #{u.email}" }
    end

  end

  namespace :user do
    desc 'Create a user without a password; they can request one from the UI. `RAILS_ENV=production bundle exec rake chf:user:create[newuser@chemheritage.org]`'
    task :create, [:email] => :environment do |t, args|
      u = User.create!(email: args[:email])
      puts "User created with email address #{u.email}."
      puts "Please request a password via the 'Forgot your password?' page."
    end

    namespace :test do
      desc 'Create a test user with a password; not secure for actual users'
      task :create, [:email, :pass] => :environment do |t, args|
        u = User.create!(email: args[:email], password: args[:pass])
        puts "Test user created"
      end
    end
  end

  namespace :dzi do
    desc "set bucket configuration"
    task :configure_bucket => :environment do
      client = CHF::CreateDziService.s3_client!

      client.put_bucket_cors(
        bucket: CHF::CreateDziService.bucket_name,
        cors_configuration: {
          cors_rules: [
            {
              allowed_methods: ["GET"],
              allowed_origins: ["*"],
              max_age_seconds: 12.hours,
              allowed_headers: ["*"]
            }
          ]
        }
      )

      client.put_bucket_acl(
        acl: CHF::CreateDziService.acl,
        bucket: CHF::CreateDziService.bucket_name,
      )
    end

    desc "ensure s3 acl set properly on all objects"
    task :set_acl => :environment do
      client = CHF::CreateDziService.s3_client!
      bucket = CHF::CreateDziService.s3_bucket!
      progress = ProgressBar.create(total: nil)
      i = 0
      bucket.objects.each do |s3_obj|
        i += 1
        client.put_object_acl(bucket: CHF::CreateDziService.bucket_name, key: s3_obj.key, acl: CHF::CreateDziService.acl)
        if i % 10 == 0
          progress.increment
          progress.title = i
        end
      end
      progress.title = i
      progress.finish
    end


    # To lazy-create, call as `rake chf:dzi:push_all[lazy]`, or also with WORK_IDS="xd07gs68,zg64tk92g,etc"
    desc "create and push all dzi to s3"
    task :push_all, [:option_list] => :environment do |t, args|
      lazy = args.to_a.include?("lazy")
      backtrace = args.to_a.include?("backtrace")


      condition = if ENV['WORK_IDS'].blank? && ENV['FILE_SET_IDS'].blank?
        []
      else
        { id: [] }.tap do |h|
          if ENV['WORK_IDS'].present?
            h[:id].concat GenericWork.where(id: ENV['WORK_IDS'].split(",")).collect(&:file_set_ids).flatten
          end
          if ENV['FILE_SET_IDS'].present?
            h[:id].concat ENV['FILE_SET_IDS'].split(",")
          end
        end
      end

      errors = []
      total = FileSet.where(condition).count
      progress = ProgressBar.create(total: total, format: "%t %a: |%B| %p%% %e", :smoothing => 0.5)
      $stderr.puts "Creating dzi for #{total} filesets"
      # Get this from Solr instead would be faster, but it's a pain
      FileSet.find_each(condition) do |fs|
        begin
          # A bit expensive to get all the id and checksums, is there a faster way? Not sure.
          file = fs.original_file
          if file
            CHF::CreateDziService.new(file.id, checksum: file.checksum.value).call(lazy: lazy)
          else
            Rails.logger.warn("No original file for #{fs.id}? Could not push DZI")
          end
          progress.increment
        rescue StandardError => e
          errors << file.id
          msg = "Could not create and push DZI for #{file.id}: #{e.inspect}"
          msg += "\n   #{e.backtrace.join("\n   ")}" if backtrace
          progress.log(msg)
        end
      end
      progress.finish
      if errors.count
        $stderr.puts "#{errors.count} errors"
      end
    end

    # not sure why these 'require' are required
    require 'hydra/pcdm'
    desc "remove .dzi and files not associated with current fedora data"
    task :clean_orphaned => :environment do |t, args|
      # get a list of ALL top-level objects, which will be just .dzi files.
      bucket = CHF::CreateDziService.s3_bucket!
      scope = bucket.objects(delimiter: '/')

      $stderr.puts "Scanning S3 bucket '#{bucket.name}' for .dzi of file IDs not currently in repo '#{ActiveFedora.fedora.base_uri}'...\n\n"

      # Don't know total, too expensive to look up.
      progress = ProgressBar.create(:total => nil)
      i = 0
      deleted = []

      objects = scope.each do |s3_obj|
        i += 1

        file_id, checksum = CHF::CreateDziService.parse_dzi_file_name( s3_obj.key )

        # Believe it or not, this seems to be the way to figure out file existence, took
        # me hours to figure out. Not sure how many round-trips to fedora it will
        # take, but this is good enough, i'm tired.
        file_obj = Hydra::PCDM::File.new(file_id)
        exists  = begin
                    file_obj.persisted?
                  rescue Ldp::Gone
                    false
                  end
        stored_checksum = begin
                            file_obj.checksum.value
                          rescue Ldp::Gone
                            false
                          end

        unless exists && stored_checksum == checksum
          # either file_id does not exist, or no longer has this checksum.
          # orphaned!
          deleted << [file_id, checksum]

          #first .dzi, so it won't be visible to front-end
          s3_obj.delete

          # then any associated tiles
          bucket.objects(prefix: s3_obj.key.sub(/\.dzi$/, '_files/')).each do |tile_obj|
            progress.increment
            tile_obj.delete
          end
        end
        progress.increment
        progress.title = "#{i} scanned, #{deleted.count} deleted"
      end
      progress.finish

      # Have to do this a bit hackily, we'll actually iterate through every
      # key, but the sdk #list_objects methods gets 'directories' out
      # for us with #prefix
      $stderr.puts "\nScanning for orphaned _files/ tiles...\n\n"
      progress = ProgressBar.create(:total => nil)
      i = 0
      deleted = []
      client = CHF::CreateDziService.s3_client!
      marker = nil
      begin
        s3_response = client.list_objects(bucket: CHF::CreateDziService.bucket_name, marker: marker, delimiter: '/')
        marker = s3_response.next_marker
        s3_response.common_prefixes.collect(&:prefix).each do |prefix|
          i += 1
          dzi_file_name = prefix.sub(/_files\/$/, '.dzi')
          unless bucket.object(dzi_file_name).exists?
            # delete tiles
            deleted << prefix
            bucket.objects(prefix: prefix).each do |tile_obj|
              progress.increment
              tile_obj.delete
            end
          end
          progress.increment
          progress.title = "~#{i} sets scanned, #{deleted.count} deleted"
        end
      end while marker != nil
      progress.finish
    end
  end

  namespace :iiif do
    desc 'Delete all files in both iiif caches. `RAILS_ENV=production bundle exec rake chf:iiif:clear_caches`'
    task :clear_caches do
      # We're not doing an :environment rake dep for speed so need to load
      # our CHF::Env.
      require Rails.root.join("app", "models", "chf", "env").to_s
      Pathname.new(CHF::Env.lookup(:riiif_originals_cache)).children.each { |p| p.rmtree }
      Pathname.new(CHF::Env.lookup(:riiif_derivatives_cache)).children.each { |p| p.rmtree }
    end

    # Note this will not work on non-public images
    desc 'ping iiif server to fetch all originals of publicly-visible images from fedora. `RAILS_ENV=production IIIF_INTERNAL_URL=http://[IP]:8182/iiif/2 bundle exec rake chf:iiif:preload_originals`'
    task :preload_originals => :environment do
      total = FileSet.count

      $stderr.puts "Ping'ing iiif server at `#{CHF::Env.lookup(:iiif_internal_url)}` for all #{total} FileSet original files"

      progress = ProgressBar.create(total: total, format: "%t %a: |%B| %p%% %e")

      iiif_base = CHF::Env.lookup(:iiif_internal_url)
      errors = 0

      # There's probably a faster way to do this, maybe from Solr instead of fedora?
      # Or getting original_file_id without the extra fetch? Not sure. This is slow.
      FileSet.find_each do |fs|
        if original_file_id = fs.original_file.try(:id)
          preloader = CHF::Utils::IiifOriginalPreloader.new(original_file_id, iiif_base: iiif_base)
          response = preloader.ping_to_preload

          if response.status != 200
            errors += 1
            progress.log "Unexpected #{response.status} response (#{errors} total) at #{iiif_base} #{preloader.ping_path}"
          end

          progress.increment
        end
      end
      progress.finish
      if errors > 0
        $stderr.puts "#{errors} total error responses out of #{total} info requests"
      end
    end
  end
end
