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

  def imgix_url(file_set_id)
    host = CHF::Env.lookup(:imgix_host)
    raise ArgumentError.new("Need CHF::Env.lookup(:imgix_host)") unless host.present?
    "//#{host}/#{CGI.escape file_set_id}"
  end

  # create an image tag for a 'member' (could be fileset or child work) thumb,
  # for use on show page. Calculates proper image tag based on lazy or not,
  # use of riiif for images or not, and desired size. Includes proper
  # attributes for triggering viewer, analytics, etc.
  #
  # if use_image_server is false, size_key is ignored and no srcsets are generated,
  # we just use the stock hydra-derivative created image labelled 'jpeg'
  def member_image_tag(parent_id:, member:, size_key: nil, lazy: false, use_image_server: CHF::Env.lookup(:use_image_server_on_show_page))
    base_width = size_key == :large ? 525 : 208

    args = {
      class: ["show-page-image-image"],
      alt: "",
      data: {
        trigger: "chf_image_viewer",
        member_id: member.representative_id,
        aspectratio: "#{member.representative_width}/#{member.representative_height}", # used for lazysizes-aspectratio
        analytics_category: "Work",
        analytics_action: "view",
        analytics_label: parent_id
      }
    }

    src_args = if member.riiif_file_id.nil?
      # if there's no image, show the default thumbnail (it gets indexed)
      {
        src:  member.thumbnail_path
      }
    elsif use_image_server
      {
        src: riiif_image_url(member.riiif_file_id, format: "jpg", size: "#{base_width},"),
        srcset: riiif_image_srcset_pixel_density(member.riiif_file_id, base_width)
      }
    else
      {
        src: main_app.download_path(member.representative_id, file: "jpeg")
      }
    end

    if lazy
      args[:class] << "lazyload"
      args[:data].merge!(src_args)
    else
      args.merge!(src_args)
    end

    image_tag(args.delete(:src), args)
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
