module CHF
  # Commpletely overridden, from scratch, from CurationConcerns.
  # https://github.com/samvera/curation_concerns/blob/v1.7.8/app/jobs/create_derivatives_job.rb

  # We completely reimplement ourselves. the existing implementation was not
  # super useful, although we copy and paste some parts. We:
  #
  # 1) Assume runnning on a server NOT the app server, get file from fedora, and
  #    make sure to clean up temporary working copy.
  # 2) push to S3 (under key "#{file_set_id}_checksum#_{file_checksum}/derivative_file_name"). That file_set_ids are equally distributed hex makes this a good S3 key.
  #     checksum is used to make cached values self-busting if file changes. If caller already has
  #     the checksum, pass it in to avoid an expensive lookup.
  # 3) Use optimal settings for a small sized thumbnail, currently use vips
  #    instead of im/gm, it's much faster and uses less RAM.
  #
  # This service itself has info on what image derivatives to create, it's no longer
  # going through the hydra derivatives architecture.
  #
  # This has to be called AFTER the file is really added to fedora, _should_ be
  # because of how it's called by sufia 7 stack.
  # See https://bibwild.wordpress.com/2017/07/11/on-hooking-into-sufiahyrax-after-file-has-been-uploaded/
  #     https://github.com/samvera/curation_concerns/blob/1d5246ebb8bccae0a385280eda10a7dbdc1d517d/app/jobs/characterize_job.rb#L22
  #
  # Also provides some class methods for file name calculation.
  #
  # By default it will create and write the derivatives whether they exist or not,
  # initialize with `.new(lazy: true)` to only write if not already present on S3 under expected file name.
  #
  # If you only want to create SOME derivatives, you can pass one or more
  # "styles:" and/or "typse:" to _initializer_. Can be combined with lazy.
  #
  #     CreateDerivativesOnS3Service.new(file_set, file_id, only_styles: "thumb").call
  #     CreateDerivativesOnS3Service.new(file_set, file_id, only_types: ["large_dl", "medium_dl"]).call
  #
  # We use some multi-threaded concurrency to create each derivative in parallel, inside
  # this class.
  #
  # POSSIBLE IMPRVOVEMENT: Switch to ruby-vips instead of shell out to vips command line.
  #  See: https://github.com/jcupitt/libvips/issues/777#issuecomment-337831511
  class CreateDerivativesOnS3Service
    WORKING_DIR_PARENT = CHF::Env.lookup(:derivative_job_tmp_dir)

    IMAGE_TYPES = {
      # Thumb-type widths in pixels are based on our CSS, the sizes we'll need
      # to display on actual pages. May have to change if CSS changes. If you change
      # them, you'll have to re-gen relevant derivatives to get them to have new sizes.

      # small thumb for multiple images on show page. These are tricky cause they
      # are really different sizes responsively, but we just pick one to resize to
      # as standard for now.
      thumb_standard: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:standard], style: :thumb, suffix: '.jpg').freeze,
      thumb_standard_2X: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:standard] * 2, style: :thumb, suffix: '.jpg').freeze,

      # giant thumb for big hero image on show page
      thumb_hero: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:large], style: :thumb, suffix: '.jpg').freeze,
      thumb_hero_2X: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:large] * 2, style: :thumb, suffix: '.jpg').freeze,

      # thumbs on viewer list
      thumb_mini: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:mini], style: :thumb, suffix: '.jpg').freeze,
      thumb_mini_2X: OpenStruct.new(width: ImageServiceHelper::THUMB_BASE_WIDTHS[:mini] * 2, style: :thumb, suffix: '.jpg').freeze,


      # downloadable ones at sizes we just picked

      dl_large: OpenStruct.new(width: ImageServiceHelper::DOWNLOAD_WIDTHS[:large], label: "Large JPG", style: :download, suffix: '.jpg').freeze,
      dl_medium: OpenStruct.new(width: ImageServiceHelper::DOWNLOAD_WIDTHS[:medium], label: "Medium JPG", style: :download, suffix: '.jpg').freeze,
      dl_small: OpenStruct.new(width: ImageServiceHelper::DOWNLOAD_WIDTHS[:small], label: "Small JPG", style: :download, suffix: '.jpg').freeze,
      dl_full_size: OpenStruct.new(width: nil, label: "Original-size JPG", style: :download, suffix: '.jpg').freeze,
    }.freeze

    class_attribute :acl
    self.acl = 'public-read'

    class_attribute :cache_control
    self.cache_control = "max-age=31536000" # one year in seconds.

    # Using Aws::S3 directly appeared to give us a lot faster bulk upload
    # than via fog.
    def self.s3_bucket!
      s3_resource.bucket(CHF::Env.lookup!('derivative_s3_bucket'))
    end

    def self.s3_path(file_set_id:, file_checksum:, type_key:)
      defn = get_type_defn(type_key)
      "#{file_set_id}_checksum#{file_checksum}/#{Pathname.new(type_key.to_s).sub_ext(defn.suffix)}"
    end

    def self.valid_s3_keys
      @valid_s3_keys ||= IMAGE_TYPES.collect(&:to_s).flatten.freeze
    end

    # filename_base, if provided, is used to make more human-readable
    # 'save as' download file names, and triggers content-disposition: attachment.
    #
    # These can be slow-ish to create due to creating a signed url.
    #
    # By default redirects to an S3 URL that will have content-disposition headers forcing
    # download with a good filename. `include_content_disposition: false` will omit content-disposition headers.
    def self.s3_url(file_set_id:, file_checksum:, type_key:, filename_base: nil, include_content_disposition: true)
      obj = s3_bucket!.object(s3_path(file_set_id: file_set_id, file_checksum: file_checksum, type_key: type_key))

      if filename_base
        defn = get_type_defn(type_key)
        # secure URL supplies kind of security, assuming the app won't generate
        # this link unless you have access. But we haven't really ensured that
        # universally or made secure links everywhere, so this is not yet security.

        file_name = "#{filename_base}_#{type_key.to_s}.#{defn.suffix.sub(/^\./, '')}"

        obj.presigned_url(:get,
                          expires_in: 3.days.to_i, # no hurry
                          response_content_disposition: include_content_disposition ? ApplicationHelper.encoding_safe_content_disposition(file_name) : "")
      else
        obj.public_url
      end
    end

    # Creating a new Aws::S3::Resource is surprisingly costly, create a global
    # one and cache it.
    def self.s3_resource
      @s3_resource ||= Aws::S3::Resource.new(
        credentials: Aws::Credentials.new(CHF::Env.lookup('aws_access_key_id'), CHF::Env.lookup('aws_secret_access_key')),
        region: CHF::Env.lookup!('derivative_s3_bucket_region')
      )
    end
    self.s3_resource

    attr_reader :file_set, :file_id, :lazy, :thread_pool, :only_styles, :only_types

    # @param [FileSet] file_set
    # @param [String] file_id identifier for a Hydra::PCDM::File
    def initialize(file_set, file_id, file_checksum: nil, lazy: false, only_styles: nil, only_types: nil)
      @file_set = file_set
      @file_id = file_id
      @file_checksum = file_checksum
      @lazy = !!lazy
      @only_styles = Array(only_styles).collect(&:to_s) if only_styles
      @only_types = Array(only_types).collect(&:to_s) if only_types
    end

    def file_set_content_type
      @file_set_content_type ||= file_set.mime_type
    end

    # If not already set, we have to fetch from fedora, which is kinda slow with AF on wells.
    def file_checksum
      @file_checksum ||= Hydra::PCDM::File.find(file_id).checksum.value
    end

    # We set working dir state for duration of this method so we don't need to pass
    # it to helper methods, definitely not thread-safe, don't share instances
    # between threads, you weren't going to anyway.
    def call

      # NOTE: When audio files are ingested, we bypass this method and
      # use methods in AudioDerivativeMaker instead. The code in this
      # class is focused on creating image files and could not easily be
      # adapted to the special needs of audio files. We decided not to
      # refactor this file and AudioDerivativeMaker into one more general file
      # for expediency, as we are reaching the end of the line for Sufia
      # as of Spring 2019.

      # START BYPASS CODE
      if CHF::AudioDerivativeMaker.is_audio?(file_set_content_type)
        file_info = {
          :file_id => file_id, :file_set => file_set,
          :file_set_content_type => file_set_content_type,
          :file_checksum => file_checksum
        }
        deriv_maker = CHF::AudioDerivativeMaker.new(file_info, lazy)
        return deriv_maker.create_and_upload_derivatives()
      end
      # END BYPASS CODE

      futures = []

      # mktmpdir will clean up tmp dir and all it's contents for us
      Dir.mktmpdir("fileset_#{file_set.id}_", WORKING_DIR_PARENT) do |temp_dir|
        desired_types = IMAGE_TYPES.collect do |type, defn|
          [type, defn] if ((only_styles.nil? || only_styles.include?(defn.style.to_s)) &&
                           (only_types.nil? || only_types.include?(key.to_s)) &&
                           style_okay_for_original_type?(defn))
        end.compact.to_h

        if lazy
          # limit to just ones that don't already exist, see if we need to do any.
          # Use concurrency for even faster.
          desired_types = desired_types.collect do |type, defn|
            Concurrent::Future.execute do
              s3_obj = self.class.s3_bucket!.object(self.class.s3_path(file_set_id: file_set.id, file_checksum: file_checksum, type_key: type))
              [type, defn] unless s3_obj.exists?
            end
          end.collect(&:value!).compact.to_h
        end

        return if desired_types.empty? # avoid fetch on lazy with nothing to update

        @working_dir = temp_dir
        @working_original_path = CHF::GetFedoraBytestreamService.new(file_id, local_path: File.join(@working_dir, "original")).get


        desired_types.each_pair do |key, defn|
          future = if file_set_content_type == "application/pdf"
              create_pdf_jpg_thumb_future(width: defn.width, type_key: key)
            else
              create_image_jpg_derivative_future(width: defn.width, type_key: key)
            end
          futures << future
        end

        futures.compact.each(&:value!)
        futures.clear

        # We COULD  try do  default behavior for types we don't handle here, calling #create_derivatives on
        # fileset, to get any superclass stack derivatives from sufia, say PDF
        # related and such. But we're not for now, we don't use em, don't do it,
        # if we want em, we should copy the kinds of derivativds we want here, and
        # do em right.
        # if desired_types.count == 0
        #   file_set.create_derivatives(working_original_path)
        # end
      end
    ensure
      @working_dir = nil
      @working_original_path = nil
    end

    protected

    def self.get_type_defn(type_key)
      IMAGE_TYPES[type_key.to_sym] or raise ArgumentError.new("No image type definition found for #{type_key}")
    end
    def get_type_defn(type_key)
      self.class.get_type_defn(type_key)
    end

    def style_okay_for_original_type?(style_defn)
      if file_set_content_type.start_with?("image/")
        return true # all good
      elsif file_set_content_type == 'application/pdf'
        # only thumbs for PDFs
        return style_defn.style == :thumb
      else
        # we don't know how to create derivs for it at present. We could try to use
        # # sufia super implementation instead, but we're not right now.
        return false
      end
    end

    def working_dir
      @working_dir || (raise TypeError.new("unexpected nil @working_dir"))
    end

    def working_original_path
      @working_original_path || (raise TypeError.new("Unexpected nil @working_original_path"))
    end

    def thumbnail_shell_args(type_key, width, quality, output_path)
      style = get_type_defn(type_key).style
      sRGB_profile_path = Rails.root.join("vendor", "icc", "sRGB2014.icc").to_s

      vips_jpg_params = if style.to_s == "thumb"
        "[Q=#{quality},interlace,optimize_coding,strip]"
      else
        # could be higher Q for downloads if we want, but we don't right now
        # We do avoid striping metadata, no 'strip' directive.
        "[Q=#{quality},interlace,optimize_coding]"
      end
      extra_args = if style.to_s == "thumb"
        # for thumbs, ensure convert to sRGB and strip embedded profile,
        # as browsers assume sRGB.
        ["--eprofile", sRGB_profile_path, "--delete"]
      else
        []
      end

      # if we're not resizing, way more convenient to use a different
      # vips command line.
      args = if width
        # Due to bug in vips, we need to provide a height constraint, we make
        # really huge one million pixels so it should not come into play, and
        # we're constraining proportionally by width.
        # https://github.com/jcupitt/libvips/issues/781
        [
          "vipsthumbnail",
          working_original_path,
          *extra_args,
          "--size", "#{width}x1000000",
          "-o", "#{output_path}#{vips_jpg_params}"
        ]
      else
        [ "vips", "copy",
          working_original_path,
          *extra_args,
          "#{output_path}#{vips_jpg_params}"
        ]
      end
      args
    end


    def sharpen_shell_args(type_key, width, input_path, output_path)
      sigma = (width > 150) ? 3 : 1
      sigma_string = sigma.to_s
      result = [
        "vips",  "sharpen",
         input_path,
         output_path,
        "--sigma",     sigma_string,
        "--x1",        "2"   ,
        "--y2",        "10"  , # (don't brighten by more than 10 L*)
        "--y3",        "10"  , # (can darken by up to 20 L*)
        "--m1",        "0"   , # (no sharpening in flat areas)
        "--m2",        "3"   , # (some sharpening in jaggy areas)
      ]
      result
    end

    def add_border_shell_args(old_width, old_height, border_width, input_path, output_path)
      border_color = "5, 9, 57" # #050939

      ['vips',
       'embed',
        input_path,
        output_path,
        border_width,
        border_width,
        old_width + border_width * 2,
        old_height + border_width * 2,
        '--extend',
        'background',
        '--background',
        border_color
      ]
    end

    # create and push to s3. Operates on an IMAGE (tiff, jpeg, whatever) input.
    #
    # returns a Future
    #
    # For thumbnails, we use more aggressive image conversion parameters, as opposed
    # to downloads. Later, thumbs might also apply some cropping to enforce maximum
    # aspect ratios. For thumbnail aggressive conversion parameters, some background:
    #     * http://www.imagemagick.org/Usage/thumbnails/
    #     * https://developers.google.com/speed/docs/insights/OptimizeImages
    #     * http://libvips.blogspot.com/2013/11/tips-and-tricks-for-vipsthumbnail.html
    #     * https://github.com/jcupitt/libvips/issues/775
    def create_image_jpg_derivative_future(width:, type_key:)
      defn = get_type_defn(type_key)
      style = defn.style
      s3_obj = self.class.s3_bucket!.object(self.class.s3_path(file_set_id: file_set.id, file_checksum: file_checksum, type_key: type_key))
      output_path = Pathname.new(working_dir).join(type_key.to_s).sub_ext(defn.suffix).to_s
      args = thumbnail_shell_args(type_key, width, 80, output_path)
      Concurrent::Future.execute(executor: Concurrent.global_io_executor) do
        TTY::Command.new(printer: :null).run(*args)
        s3_obj.upload_file(output_path,
                           acl: acl,
                           content_type: "image/jpeg",
                           content_disposition: ("attachment" if style != :thumb),
                           cache_control: cache_control)
      end
    end

    def get_height_shell_args(image_path)
      ['vipsheader', '-f', 'Ysize', image_path]
    end

    # Takes a pdf, makes a thumb. Includes small border around thumb, since this
    # works better for typical white-bg print-like PDFs.
    def create_pdf_jpg_thumb_future(width:, type_key:)
      defn = get_type_defn(type_key)
      style = defn.style

      #paths
      output_path = Pathname.new(working_dir).join(type_key.to_s).sub_ext(defn.suffix).to_s
      blurry_output_path = output_path.sub('.jpg', "_blurry.jpg")
      sharp_output_path = output_path.sub('.jpg', "_sharp.jpg")

      # image widths
      border_width = 1
      width_minus_borders = width - (2 * border_width)

      # shell commands
      thumbnail_sh = thumbnail_shell_args(type_key, width_minus_borders, 98, blurry_output_path)
      get_height_sh = get_height_shell_args (blurry_output_path)
      sharpen_sh = sharpen_shell_args(type_key, width_minus_borders, blurry_output_path, sharp_output_path)
      height_sh = get_height_shell_args(blurry_output_path)

      s3_obj = self.class.s3_bucket!.object(self.class.s3_path(file_set_id: file_set.id, file_checksum: file_checksum, type_key: type_key))

      Concurrent::Future.execute(executor: Concurrent.global_io_executor) do
        cmd = TTY::Command.new(printer: :null)
        # First, create a blurry thumbnail.
        cmd.run(*thumbnail_sh)
        # Then, sharpen it.
        cmd.run(*sharpen_sh)
        # Determine its height.
        height_minus_borders = cmd.run(*height_sh).out.to_i
        # Add a border around the sharpened thumbnail.
        add_border_sh =  add_border_shell_args(width_minus_borders, height_minus_borders, border_width, sharp_output_path, output_path)
        cmd.run(*add_border_sh)
        # Upload the result to s3
        s3_obj.upload_file(output_path,
          acl: acl,
          content_type: "image/jpeg",
          content_disposition: ("attachment" if style != :thumb),
          cache_control: cache_control)
      end #concurrent future execute do
    end # method
  end
end
