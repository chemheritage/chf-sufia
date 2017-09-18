require 'concurrent'
require 'aws-sdk-s3'


module CHF
  # Needs 'vips' installed.
  # Will overwrite if it's already there on S3, unless called with `lazy:true`, which
  # is mainly useful for speed.
  #
  # s3 bucket needs CORS turned on! http://docs.aws.amazon.com/AmazonS3/latest/user-guide/add-cors-configuration.html
  #
  # For performance, pass in just a file_id, it's all we need, we try to avoid lookups,
  # but if you can pass in a checksum that you got cheaply, you'll avoid us having to get
  # it expensively.
  #
  # objects are stored in S3 with a key created from both file_id and checksum, to make them
  # self-cache-busting if the datastream at a file_id changes (versioning?). Does
  # make the s3 keys kind of non-human-readable, but I think that's okay.
  #
  # Uses a bunch of Chf::Env settings:
  # required:
  #  * aws_access_key_id
  #  * aws_secret_access_key
  #  * dzi_s3_bucket (required only in production, otherwise sensible defaults)
  # optional (cause they have defaults):
  #  * dzi_job_tmp_dir
  #  * dzi_s3_bucket_region
  #
  # Seek rake chf:dzi for tools for managing the S3 bucket contents.
  #
  # MAYBE would we better off using actual libvips bindings at https://github.com/jcupitt/ruby-vips
  #   instead of shell out? I think it probably doesn't matter.
  #
  # POSSIBLE IMPROVEMENT some cleverer concurrency stuff if two of these jobs try acting at the same
  # time, keep the out of using each others files, or let them actually share/wait
  # on each other files.
  class CreateDziService
    WORKING_DIR = CHF::Env.lookup(:dzi_job_tmp_dir)
    UPLOAD_THREADS = 128

    class_attribute :vips_command
    self.vips_command = "vips"

    class_attribute :jpeg_quality
    self.jpeg_quality = "85"

    class_attribute :cache_control
    self.cache_control = "max-age=31536000" # one year in seconds.

    class_attribute :acl
    self.acl = 'public-read'


    attr_accessor :file_id, :checksum, :s3_bucket


    def initialize(file_id, checksum: nil)
      raise ArgumentError("file_id arg can not be empty") if file_id.blank?
      @file_id = file_id
      @checksum = checksum
      @s3_bucket = self.class.s3_bucket!
    end

    # Downloads datastream and creates DZI files in WORKING_DIR,
    # uploads them to S3.
    #
    # If lazy is true, will first check to see if the .dzi file already exists
    # on S3, and if it does skip generation and upload. It doesn't check
    # to make sure all tiles are correct, just dzi file exists.
    def call(lazy: false)
      if lazy && s3_bucket.object(dzi_file_name).exists?
        return false
      end

      ensure_dirs

      fetch_from_fedora!

      create_dzi!

      upload_to_s3!

      return true
    ensure
      clean_up_tmp_files
    end

    protected

    # Fetch Hydra::PCDM::File from fedora and save to WORKING_DIR,
    # streaming for efficiency.
    def fetch_from_fedora!
      response = nil
      # We hope this is the right way to get the actual uri to fetch cheaply?
      uri = URI.parse(FileSet.translate_id_to_uri.call(file_id))

      fedora_fetch_benchmark = Benchmark.measure do
        response = Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new uri

          if ActiveFedora.fedora.user || ActiveFedora.fedora.password
            request.basic_auth(ActiveFedora.fedora.user, ActiveFedora.fedora.password)
          end

          http.request request do |response|
            open local_original_file_path, 'wb' do |io|
              response.read_body do |chunk|
                io.write chunk
              end
            end
          end
        end
      end
      Rails.logger.debug("#{self.class.name}: fetch_from_fedora: #{fedora_fetch_benchmark}")
      unless response && response.code == "200"
        raise StandardError.new("Could not fetch file from fedora: #{uri}")
      end
    end

    def create_dzi!
      dzi_benchmark = Benchmark.measure do
        # http://libvips.blogspot.com/2013/03/making-deepzoom-zoomify-and-google-maps.html
        TTY::Command.new(printer: :null).run(vips_command, "dzsave", local_original_file_path, local_dzi_base_path, "--suffix", ".jpg[Q=#{jpeg_quality}]")
      end
      Rails.logger.debug("#{self.class.name}: create_dzi: #{dzi_benchmark}")
    end

    # uploading to s3 is actually the slowest part if done serially.
    # We apply a healthy dose of concurrency.
    def upload_to_s3!
      s_time = Time.now

      # All the jpgs, which are in a _files/ dir, and subdirs of that.
      futures = []
      dir_path = Pathname.new(local_dzi_dir_path)
      # We get back full paths from FS root from Dir.glob, need to change then
      # to relative to working dir to get the S3 keys we want.
      path_prefix_re = /\A#{Regexp.quote(WORKING_DIR.end_with?('/') ? WORKING_DIR : WORKING_DIR + '/')}/

      Dir.glob("#{dir_path}/**/*.jpg").each do |full_path|
        futures << Concurrent::Future.execute(executor: self.class.thread_pool_executor) do
          s3_bucket.
            object(full_path.sub(path_prefix_re, '')).
            upload_file(full_path, acl: acl, cache_control: cache_control)
        end
      end

      # wait on em all
      futures.collect(&:value)

      # any errors? Raise one of em.
      if rejected = futures.find(&:rejected?)
        raise rejected.reason
      end

      # upload .dzi AFTER all the tiles, so it's not there until they are
      s3_bucket.
        object(dzi_file_name).
        upload_file(local_dzi_file_path, acl: acl, cache_control: cache_control)


      Rails.logger.debug("#{self.class.name}: upload_to_s3: #{Time.now - s_time}")
    end

    def self.thread_pool_executor
      @thread_pool ||= Concurrent::ThreadPoolExecutor.new(
          min_threads:     UPLOAD_THREADS,
          max_threads:     UPLOAD_THREADS,
          auto_terminate:  true,
          idletime:        60, # 1 minute. shouldn't matter, we have min and max the same
          max_queue:       0, # unlimited
          fallback_policy: :abort # shouldn't matter -- 0 max queue
      )
    end
    self.thread_pool_executor # init now

    # include the checksum so it's self-cache-busting if file at this URL
    # changes, say, due to versioning. HOWEVER, this does make indexing
    # somewhat slower.
    def self.base_file_name(file_id, checksum)
      CGI.escape "#{file_id}_checksum#{checksum}"
    end

    # returns [file_id, checksum]
    def self.parse_dzi_file_name(base_file_name)
      parts = CGI.unescape(base_file_name.sub(/\.dzi$/, '')).split("_checksum")
      return parts.first, parts.second
    end

    # oops, confusingly need to escape the base_file_name AGAIN. Maybe we should
    # not actually have escaped it in the key name, not sure.
    def self.s3_dzi_url_for(file_id:, checksum:)
      "//#{CHF::Env.lookup('dzi_s3_bucket')}.s3.amazonaws.com/#{CGI.escape base_file_name(file_id, checksum)}.dzi"
    end
    def base_file_name
      @base_file_name ||= self.class.base_file_name(file_id, checksum)
    end

    # If not already set, we have to fetch from fedora, which is kinda slow with AF.
    # TODO, we can make this one fetch, not two.
    def checksum
      @checksum || Hydra::PCDM::File.find(file_id).checksum.value
    end

    def dzi_file_name
      "#{base_file_name}.dzi"
    end


    def local_original_file_path
      @local_original_file_path ||= Pathname.new(WORKING_DIR).join("#{base_file_name}.original").to_s
    end

    def local_dzi_base_path
      @local_dzi_path || Pathname.new(WORKING_DIR).join(base_file_name).to_s
    end
    def local_dzi_file_path
      "#{local_dzi_base_path}.dzi"
    end
    def local_dzi_dir_path
      "#{local_dzi_base_path}_files"
    end

    def clean_up_tmp_files
      FileUtils.rm_rf([local_original_file_path, local_dzi_file_path, local_dzi_dir_path])
    end

    def ensure_dirs
      FileUtils.mkdir_p WORKING_DIR
    end

    def self.bucket_name
      CHF::Env.lookup('dzi_s3_bucket') || (raise ArgumentError.new("No bucket name provided! Need a `CHF::Env.lookup('dzi_s3_bucket')`"))
    end

    def self.s3_client!
      Aws::S3::Client.new(
        credentials: Aws::Credentials.new(CHF::Env.lookup('aws_access_key_id'), CHF::Env.lookup('aws_secret_access_key')),
        region: CHF::Env.lookup('dzi_s3_bucket_region')
      )
    end

    # Using Aws::S3 directly appeared to give us a lot faster bulk upload
    # than via fog.
    def self.s3_bucket!
      Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(CHF::Env.lookup('aws_access_key_id'), CHF::Env.lookup('aws_secret_access_key')),
        region: CHF::Env.lookup('dzi_s3_bucket_region')
      ).bucket(bucket_name)
    end

  end
end
