# Override to add a timeout option to fedora.yml config, so we can increase it.
# Should be in some future ActiveFedora after 11.4.0.
# https://github.com/samvera/active_fedora/issues/1105

# timeout value in fedora.yml is in SECONDS

if Gem.loaded_specs["active-fedora"].version >= Gem::Version.new('11.4.0')
   msg = "
   Please check and make sure this patch is still needed\
  at #{__FILE__}:#{__LINE__}\n\n"
   $stderr.puts msg
   Rails.logger.warn msg
end

module ActiveFedoraOverride
  def authorized_connection
    super.tap do |conn|
      if @config[:timeout] && @config[:timeout].to_i > 0
        conn.options[:timeout] = @config[:timeout].to_i
      end
    end
  end
end

ActiveFedora::Fedora.class_eval do
  prepend ActiveFedoraOverride unless self.class.include?(ActiveFedoraOverride)
end
