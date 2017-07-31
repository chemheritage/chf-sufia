module CHF
  module Utils
    # Ping the riiif server with a HEAD info request for a given file id, to trigger
    # caching of original asset on riiif server.
    #
    # You need config :iiif_internal_url set, for instance maybe IIIF_INTERNAL_URL=http://localhost:3000
    # if you really want to ping your dev server.
    #
    #     CHF::Utils::RiiifOriginalPreloader.new(file_id).ping_to_preload
    #
    # NOTE: This does no auth, so will not work on non-public images
    class RiiifOriginalPreloader
      include ImageServiceHelper

      attr_reader :file_id, :riiif_base
      def initialize(file_id, riiif_base: CHF::Env.lookup(:iiif_internal_url))
        @file_id = file_id
        @riiif_base = riiif_base
        unless riiif_base.present?
          raise ArgumentError, "Need an :iiif_internal_url config. Can set in env with IIIF_INTERNAL_URL=http://localhost:3000 or IIIF_INTERNAL_URL=https://$internal_riiif_ip"
        end
      end

      # Returns Faraday::Response
      def ping_to_preload
        conn = Faraday.new(riiif_base)
        conn.head ping_path
      end

      def ping_path
        case CHF::Env.lookup(:image_server)
        when 'riiif'
          Riiif::Engine.routes.url_helpers.info_path(file_id, locale: nil)
        when 'cantaloupe'
          "/iiif/2/#{CGI.escape(file_id)}/info.json"
        end
      end
    end
  end
end
