# Hack to monkey-patch solr_wrapper to get the checksum
# file from archive.apache.org instead of www.us.apache.org .

# This monkey patch is based on :
# https://github.com/cbeer/solr_wrapper/pull/119/files
# When the patch is accepted, you can simply remove this file
# as well as the reference to it in /chf-sufia/lib/tasks/dev.rake

if Gem.loaded_specs["solr_wrapper"].version >  Gem::Version.new('2.0.0')
  puts("""    The solr_wrapper gem has been upgraded. Time to
    remove the monkey-patch in
       * lib/tasks/dev.rake
       * lib/solr_wrapper_patch.rb .
  """)
end

module SolrWrapper
  class ChecksumValidator
      def checksumurl(suffix)
        "http://archive.apache.org/dist/lucene/solr/#{config.static_config.version}/solr-#{config.static_config.version}.zip.#{suffix}"
      end
  end
end