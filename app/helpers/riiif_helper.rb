module RiiifHelper

  # Returns the IIIF info.json document, suitable as an OpenSeadragon tile source/
  #
  # Returns relative url unless we've defind a riiif server in config/environments/*.rb
  def riiif_info_url (riiif_file_id)
    path = riiif.info_path(riiif_file_id, locale: nil)
    if Rails.configuration.respond_to? :riiif_server
      return URI.join(Rails.configuration.riiif_server, path).to_s
    else
      return path
    end
  end

  # Request an image URL from the riiif server. Format, size, and quality
  # arguments are optional, but must be formatted for IIIF api.
  # May make sense to make cover methods on top of this one
  # for specific images in specific places.
  #
  # Defaults copied from riiif defaults. https://github.com/curationexperts/riiif/blob/67ff0c49af198ba6afcf66d3db9d3d36a8694023/lib/riiif/routes.rb#L21
  #
  # Returns relative url unless we've defind a riiif server in config/environments/*.rb
  def riiif_image_url(riiif_file_id, format: 'jpg', size: "full", quality: 'default')
    path = riiif.image_path(riiif_file_id, locale: nil, size: size, format: format, quality: quality)

    if Rails.configuration.respond_to? :riiif_server
      return URI.join(Rails.configuration.riiif_server, path).to_s
    else
      return path
    end
  end

end
