module RiiifHelper

  # Returns the IIIF info.json document, suitable as an OpenSeadragon tile source/
  #
  # Returns relative url unless we've defind a riiif server in config/environments/*.rb
  def riiif_info_url (riiif_file_id)
    path = riiif.info_path(riiif_file_id, locale: nil)
    create_riiif_url(path)
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
    create_riiif_url(path)
  end

  # On show page, we just use pixel density source set, passing in the LARGEST width needed for
  # any responsiveness page layout. Sends somewhat more bytes when needed at some responsive
  # sizes, but way simpler to implement; keep from asking riiiif for even more varying resizes;
  # prob good enough.
  def riiif_image_srcset_pixel_density(riiif_file_id, base_width, format: 'jpg', quality: 'default')
    [1, BigDecimal.new('1.5'), 2, 3, 4].collect do |multiplier|
      riiif_image_url(riiif_file_id, format: "jpg", size: "#{base_width * multiplier},") + " #{multiplier}x"
    end.join(", ")
  end

  private

  def create_riiif_url(path)
    if CHF::Env.lookup(:public_riiif_url)
      url = Addressable::URI.parse(CHF::Env.lookup(:public_riiif_url))
      raise "public_riiif_url requires a valid URL with host, eg `http://host` or `//host`" if url.host.nil?
      return Addressable::URI.join(url, path).to_s
    else
      return path
    end
  end
end
