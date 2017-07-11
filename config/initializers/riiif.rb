# Get files via HTTP (they're in fedora)
Riiif::Image.file_resolver = Riiif::HTTPFileResolver.new

Riiif::Image.file_resolver.cache_path = CHF::Env.lookup(:riiif_originals_cache)
Riiif::Image.cache = ActiveSupport::Cache::FileStore.new(CHF::Env.lookup(:riiif_derivatives_cache))

# Tell RIIIF how to resolve the identifier to a URI in Fedora
Riiif::Image.file_resolver.id_to_uri = lambda do |id|
  ActiveFedora::Base.id_to_uri(CGI.unescape(id)).tap do |url|
    Rails.logger.info "Riiif resolved #{id} to #{url}"
  end
end

Riiif::Image.info_service = lambda do |id, _file|
  # id will look like a path to a pcdm:file
  # (e.g. rv042t299%2Ffiles%2F6d71677a-4f80-42f1-ae58-ed1063fd79c7)
  # but we just want the id for the FileSet it's attached to.

  # Capture everything before the first slash
  fs_id = id.sub(/\A([^\/]*)\/.*/, '\1')
  resp = ActiveFedora::SolrService.get("id:#{fs_id}")
  doc = resp['response']['docs'].first
  raise "Unable to find solr document with id:#{fs_id}" unless doc
  { height: doc['height_is'], width: doc['width_is'] }
end

# Note that this is translated to an `expires` argument to the
# ActiveSupport::Cache::Store in use, by default the host application's
# Rails.cache. Some cache stores may not automatically purge expired content,
# such as the default FileStore.
# http://guides.rubyonrails.org/caching_with_rails.html#cache-stores
Riiif::Engine.config.cache_duration_in_days = 30
