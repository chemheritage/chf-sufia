module CHF
  module Utils
    # Ping the riiif server with a HEAD info request for a given file id, to trigger
    # caching of original asset on riiif server.
    #
    # You need config :public_riiif_url set, for instance maybe PUBLIC_RIIIF_URL=http://localhost:3000
    # if you really want to ping your dev server.
    #
    # Even in production, you may want to set it to the internal AWS IP, for instance
    # on command line before running chf:riiif:preload_originals task.
    #
    #     CHF::Utils::RiiifOriginalPreloader.new(file_id).ping_to_preload
    class RiiifOriginalPreloader
      include RiiifHelper

      attr_reader :file_id, :riiif_base
      def initialize(file_id, riiif_base: CHF::Env.lookup(:internal_riiif_url))
        @file_id = file_id
        @riiif_base = riiif_base
        unless riiif_base.present?
          raise ArgumentError, "Need an :internal_riiif_url config. Can set in env with INTERNAL_RIIIF_URL=http://localhost:3000 or INTERNAL_RIIIF_URL=https://$internal_riiif_ip"
        end
      end

      def ping_to_preload
        conn = Faraday.new(riiif_base)
        response = conn.head ping_path
      end

      def ping_path
        Riiif::Engine.routes.url_helpers.info_path(file_id, locale: nil)
      end
    end
  end
end
