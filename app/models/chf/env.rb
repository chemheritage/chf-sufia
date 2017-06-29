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
  # You can only look up keys defined like so:
  #
  #     define_key(:some_key)
  #     define_key(:some_key, env: false) # disable ENV lookup
  #     define_key(:some_key, env: "SPECIFY_ENV_VAR") # non-defualt ENV lookup key
  #     define_key(:some_key, default: "foo")
  #     define_key(:some_key, default: -> { proc_that_provides_value} ) # will only be called once and cached
  #
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

    def define_key(name, env_key: nil, default: nil)
      @key_definitions[name.to_sym] = {
        name: name.to_s,
        env_key: env_key,
        default: default
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

    protected

    def system_env_lookup(defn)
      return NoValueProvided if defn[:env_key] == false

      if defn[:env_key] && ENV.has_key?(defn[:env_key].to_s)
        ENV[defn[:env_key].to_s]
      elsif ENV.has_key?(defn[:name].upcase)
        ENV[defn[:name].upcase]
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

    ######
    #
    #  Define keys here
    #
    ######

    define_key :public_riiif_url
    define_key :app_role
    define_key :service_level

    define_key :riiif_originals_cache, default: -> {
      Rails.env.production? ? "/var/sufia/riiif-originals" : Rails.root.join("tmp", "riiif-originals").to_s
    }
    define_key :riiif_derivatives_cache, default: -> {
      Rails.env.production? ? "/var/sufia/riiif-derivatives" : Rails.root.join("tmp", "riiif-derivatives").to_s
    }


    # Ideally these would be in local_env.yml independently,
    # but for now we calculate based on app_role value, but do it here
    # so we have one place to change.
    # Can still override with ENV or local_env.yml locally, nice!
    define_key :serve_riiif_paths, default: -> {
      lookup(:app_role).blank? || lookup(:app_role) == "riiif"
    }
    define_key :serve_app_paths, default: -> {
      lookup(:app_role).blank? || lookup(:app_role) == "app"
    }

  end
end
