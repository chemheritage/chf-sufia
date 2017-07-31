module ImageServiceHelper

  # Returns the IIIF info.json document, suitable as an OpenSeadragon tile source/
  #
  # Returns relative url unless we've defind a riiif server in config/environments/*.rb
  def iiif_info_url(image_file_id)
    path = "#{CGI.escape(image_file_id)}/info.json"
    create_iiif_url(path)
  end

  # Request an image URL from the riiif server. Format, size, and quality
  # arguments are optional, but must be formatted for IIIF api.
  # May make sense to make cover methods on top of this one
  # for specific images in specific places.
  #
  # Defaults copied from riiif defaults. https://github.com/curationexperts/riiif/blob/67ff0c49af198ba6afcf66d3db9d3d36a8694023/lib/riiif/routes.rb#L21
  #
  # Returns relative url unless we've defind a riiif server in config/environments/*.rb
  def iiif_image_url(image_file_id, format: 'jpg', size: "full", quality: 'default')
    path = iiif_image_path(image_file_id, size: size, format: format, quality: quality)
    create_iiif_url(path)
  end

  def iiif_image_path(file_id, size:, format:, quality:)
    region = 'full'
    rotation = '0'
    "#{CGI.escape(file_id)}/#{region}/#{size}/#{rotation}/#{quality}.#{format}"
  end

  # On show page, we just use pixel density source set, passing in the LARGEST width needed for
  # any responsiveness page layout. Sends somewhat more bytes when needed at some responsive
  # sizes, but way simpler to implement; keep from asking riiiif for even more varying resizes;
  # prob good enough.
  def riiif_image_srcset_pixel_density(file_id, base_width, format: 'jpg', quality: 'default')
    [1, BigDecimal.new('1.5'), 2, 3, 4].collect do |multiplier|
      iiif_image_url(file_id, format: "jpg", size: "#{base_width * multiplier},") + " #{multiplier}x"
    end.join(", ")
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

    src_args = if member.representative_file_id.nil?
      # if there's no image, show the default thumbnail (it gets indexed)
      {
        src:  member.thumbnail_path
      }
    elsif use_image_server
      {
        src: iiif_image_url(member.representative_file_id, format: "jpg", size: "#{base_width},"),
        srcset: riiif_image_srcset_pixel_density(member.representative_file_id, base_width)
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

  attr_accessor :public_host

  def public_host
    @public_host ||= begin
      url = Addressable::URI.parse(CHF::Env.lookup(:iiif_public_url))
      raise "iiif_public_url requires a valid URL with host and path, eg `http://example.com/image-service` or `//12.345.67.89/iiif/2`" if url.host.nil?
      url = url.to_s
      url << '/' if url[-1] != '/' # Make sure url ends with a slash
      url
    end
  end

  def create_iiif_url(path)
    return Addressable::URI.join(public_host, path).to_s
  end
end
