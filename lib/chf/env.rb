module CHF
  # A central place for environmental/infrastructure type configuration.
  # We still have lots of this in other places too that predates this, but
  # this is our attempt to centralize it.
  #
  # Values will be taken from, in priority order:
  #   * ENV if present -- uppercased. ENV['FOO_BAR'] for key 'foo_bar'. Or can set custom ENV key per config key.
  #   * else the config/local_env.yml file if present and has key. This file
  #     is supplied by ansible with level/role-specific values, or might
  #     be created by hand in dev if convenient.
  #   * defaults configured in this class.
  #
  # Lookup with:
  #
  #     Chf::Env.lookup("some_key")
  #
  # Or, to raise quickly on nil/blank value...
  #
  #     Chf::Env.lookup!("some_key")
  #
  # You can only look up keys defined like so:
  #
  #     define_key(:some_key)
  #     define_key(:some_key, env: false) # disable ENV lookup
  #     define_key(:some_key, env: "SPECIFY_ENV_VAR") # non-defualt ENV lookup key
  #     define_key(:some_key, default: "foo")
  #     define_key(:some_key, default: -> { proc_that_provides_value} ) # will only be called once and cached
  #
  # Since ENV values can only be strings, you can define a lambda transformation that will
  # only act on ENV values, with the :system_env_transform arg. There is a built-in
  # CHF::Env::BOOLEAN_TRANSFORM that can be used.
  #
  # All values are cached after first lookup for performance and stabilty -- this
  # kind of environmental configuration should not change for life of process.
  #
  # Keys are defined at the bottom of this file, to make sure all methods are
  # defined first! (Extract to another file? Want to make sure they get defined
  # right away so can be used at any point in boot process)
  #
  # This implementation is a bit hacky, but I think the public API is hopefully
  # good and stable.
  class Env
    NoValueProvided = Object.new
    private_constant :NoValueProvided

    BOOLEAN_TRANSFORM = lambda { |v| ! v.in?(ActiveModel::Type::Boolean::FALSE_VALUES) }

    def initialize
      @key_definitions = {}
      @local_env_path = Rails.root.join('config', 'local_env.yml')
    end

    def self.define_key(*args)
      instance.define_key(*args)
    end

    def self.lookup(*args)
      instance.lookup(*args)
    end

    def self.lookup!(*args)
      instance.lookup!(*args)
    end

    def define_key(name, env_key: nil, default: nil, system_env_transform: nil)
      @key_definitions[name.to_sym] = {
        name: name.to_s,
        env_key: env_key,
        default: default,
        system_env_transform: system_env_transform
      }
    end

    def lookup(name)
      defn = @key_definitions[name.to_sym]
      raise ArgumentError.new("No env key defined for: #{name}") unless defn

      defn[:cached_result] ||= begin
        result = system_env_lookup(defn)
        result = local_env_file_lookup(defn) if result == NoValueProvided
        result = default_lookup(defn) if result == NoValueProvided
        result = nil if result == NoValueProvided
        result
      end
    end

    # like lookup, but raises on no or blank value.
    def lookup!(name)
      lookup(name).tap do |value|
        raise TypeError, "No value was provided for `#{name}`" if value.blank?
      end
    end

    protected

    def system_env_lookup(defn)
      return NoValueProvided if defn[:env_key] == false

      value = if defn[:env_key] && ENV.has_key?(defn[:env_key].to_s)
        ENV[defn[:env_key].to_s]
      elsif ENV.has_key?(defn[:name].upcase)
        ENV[defn[:name].upcase]
      end

      if value
        defn[:system_env_transform] ? defn[:system_env_transform].call(value) : value
      else
        NoValueProvided
      end
    end

    def local_env_file_lookup(defn)
      @local_env_loaded ||= load_yaml_file
      if @local_env_loaded.has_key?(defn[:name])
        @local_env_loaded[defn[:name]]
      else
        NoValueProvided
      end
    end

    def load_yaml_file
      return {} unless File.exist?(@local_env_path)
      YAML.load(File.open(@local_env_path))
    end

    def default_lookup(defn)
      if !defn.has_key?(:default)
        NoValueProvided
      elsif defn[:default].respond_to?(:call)
        # allow a proc that gets executed on demand
        defn[:default].call
      else
        defn[:default]
      end
    end

    public

    @instance = self.new
    def self.instance
      @instance
    end

    def self.staging?
      @staging ||= ["stage", "staging"].include?(lookup(:service_level))
    end

    def self.production?
      @production ||= ["prod", "production"].include?(lookup(:service_level))
    end

    ######
    #
    #  Define keys here
    #
    ######

    define_key :iiif_public_url, default: '//localhost:3000/image-service'
    define_key :iiif_internal_url
    define_key :app_role
    define_key :service_level

    # should be a recognized image service type, or nil/false for only using hydra-derivatives thumbs
    # For recognized image service types, see [../../helpers/image_service_helper.rb] #_image_url_service
    # "iiif", "dzi_s3", or nil for legacy
    define_key :image_server_for_thumbnails
    define_key :image_server_on_viewer
    define_key :image_server_downloads


    # dzi_s3 or legacy, you can't do both at present. dzi_s3 is our new custom one,
    # legacy may have issues, but good enough for easy development env. Normally
    # should match image_server_for_thumbnails and image_server_downloads, except
    # for migrations or other unusual circumstances.
    define_key :create_derivatives_mode, default: -> { CHF::Env.lookup(:image_server_for_thumbnails) || "legacy" }

    define_key :aws_access_key_id
    define_key :aws_secret_access_key

    define_key :dzi_s3_bucket, default: -> {
      if Rails.env.development?
        "chf-dzi-dev"
      elsif staging?
        "chf-dzi-staging"
      end
      # production just configure it in env please
    }
    define_key :dzi_s3_bucket_region, default: "us-east-1"
    define_key :dzi_job_tmp_dir, default: -> {
      if Rails.env.development?
        Rails.root.join("tmp", "dzi-creation-tmp-working").to_s
      else
        # default is only called once, so mkdir_p should be fine
        FileUtils.mkdir_p("/tmp/chf-sufia/dzi-working").first
      end
    }
    define_key :dzi_auto_create, default: Rails.env.production?, system_env_transform: BOOLEAN_TRANSFORM

    define_key :derivative_job_tmp_dir, default: -> {
      if Rails.env.development?
        Rails.root.join("tmp", "derivative-tmp-working").to_s
      else
        # default is only called once, so mkdir_p should be fine
        FileUtils.mkdir_p("/tmp/chf-sufia/derivatives-working").first
      end
    }
    define_key :derivative_s3_bucket, default: -> {
      if Rails.env.development?
        "chf-derivatives-dev"
      elsif staging?
        "chf-derivatives-staging"
      end
      # production just configure it in env please
    }
    define_key :derivative_s3_bucket_region, default: "us-east-1"

    define_key :sitemap_s3_bucket, default: -> {
      if ! Rails.env.production?
        "scih-data-staging"
      end
      # production just configure it in env please
    }
    define_key :sitemap_s3_region, default: "us-east-1"



    # Only matters on a job server, used in resque-pool.yml
    define_key :job_queues, default: -> {
      if Rails.env.development? || Rails.env.test?
        "*"
      elsif lookup(:app_role) == "jobs"
        # jobs server
        "dzi, jobs_server"
      else
        # production-type app server, handling the rest currently
        "default, ingest, mailers, event"
      end
    }

    define_key :honeybadger_api_key

  end
end
