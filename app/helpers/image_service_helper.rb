module ImageServiceHelper

  #####
  #
  # Try to use these completely server-agnostic helpers, which will do the
  # right thing for image service depending on config, instead of
  # of the IIIF or other service specific ones below.
  #
  #####

  # create an image tag for a 'member' (could be fileset or child work) thumb,
  # for use on show page. Calculates proper image tag based on lazy or not,
  # use of iiif for images or not, and desired size. Includes proper
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
        srcset: iiif_image_srcset_pixel_density(member.representative_file_id, base_width)
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

  def tile_source_url(member_presenter)
    if CHF::Env.lookup(:use_image_server_on_viewer)
      iiif_info_url(member_presenter.representative_file_id)
    else
      {"type" => "image", "url" => main_app.download_path(member_presenter.representative_id, file: "jpeg")}.to_json
    end
  end

  ######
  #
  # Try to avoid these helpers below that assume specific image server API. Maybe
  # refactor out of rails helpers?
  #
  ######


  # Returns the IIIF info.json document, suitable as an OpenSeadragon tile source/
  def iiif_info_url(image_file_id)
    create_iiif_url("#{CGI.escape(image_file_id)}/info.json")
  end

  # Request an image URL from the iiif server. Format, size, and quality
  # arguments are optional, but must be formatted for IIIF api.
  # May make sense to make cover methods on top of this one
  # for specific images in specific places.
  #
  # Defaults copied from riiif defaults. https://github.com/curationexperts/riiif/blob/67ff0c49af198ba6afcf66d3db9d3d36a8694023/lib/riiif/routes.rb#L21
  def iiif_image_url(image_file_id, format: 'jpg', size: "full", quality: 'default')
    # Make these args some day? For now servs as documentation:
    region = 'full'
    rotation = '0'
    create_iiif_url("#{CGI.escape(image_file_id)}/#{region}/#{size}/#{rotation}/#{quality}.#{format}")
  end

  # On show page, we just use pixel density source set, passing in the LARGEST width needed for
  # any responsiveness page layout. Sends somewhat more bytes when needed at some responsive
  # sizes, but way simpler to implement; keep from asking riiiif for even more varying resizes;
  # prob good enough.
  def iiif_image_srcset_pixel_density(file_id, base_width, format: 'jpg', quality: 'default')
    [1, BigDecimal.new('1.5'), 2, 3, 4].collect do |multiplier|
      iiif_image_url(file_id, format: "jpg", size: "#{base_width * multiplier},") + " #{multiplier}x"
    end.join(", ")
  end

  # private may not do much in a helper, but documentation of our intent, these
  # are just meant to be called by above, not called directly.
  private

  def _iiif_public_url_addressable
    @_iiif_public_url_addressable ||= Addressable::URI.parse(CHF::Env.lookup(:iiif_public_url)).tap do |addressable|
      raise "iiif_public_url requires a valid URL with host and path, eg `http://example.com/image-service` or `//12.345.67.89/iiif/2`" if addressable.host.nil?
      unless addressable.path[-1] == ("/")
        # Make sure path ends in slash so relative joins will work as we need
        addressable.path = addressable.path + "/"
      end
    end
  end

  def create_iiif_url(path)
    return _iiif_public_url_addressable.join(path).to_s
  end
end
