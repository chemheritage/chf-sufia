module CHF

# Creates all audio derivatives and uploads them to s3.
class AudioDerivativeMaker

  AUDIO_DERIVATIVE_TYPES = {
    standard_webm: OpenStruct.new( suffix: '.webm', content_type: 'audio/webm'),
    standard_mp3:  OpenStruct.new( suffix: '.mp3',  content_type: 'audio/mpeg', rate: 44100),
    light_mp3:     OpenStruct.new( suffix: '.mp3',  content_type: 'audio/mpeg', rate: 11025),
  }

  AUDIO_FORMATS = {
    'audio/flac'   => 'flac',
    'audio/x-flac' => 'flac',
    'audio/mpeg'   => 'mp3',
    'audio/webm'   => 'webm'
  }

  attr_reader :file_id, :file_set, :file_set_content_type, :file_checksum,
  :bucket, :cache_control, :acl, :lazy,
  :working_dir_parent,
  :input_format, :derivs_we_need

  def initialize (file_info, upload_info, working_dir_parent)
    @file_id =       file_info[:file_id]
    @file_set =      file_info[:file_set]
    @file_set_content_type = file_info[:file_set_content_type]
    @file_checksum = file_info[:file_checksum]

    @bucket = upload_info[:bucket]
    @cache_control = upload_info[:cache_control]
    @acl =    upload_info[:acl]
    @lazy =   upload_info[:lazy]

    @working_dir_parent = working_dir_parent

    @input_format = AUDIO_FORMATS[@file_set_content_type]
    raise ArgumentError.new("Can't convert from format #{@file_set_content_type}") unless @input_format
  end

  # Create and upload all audio derivatives for audio file file_set
  def create_and_upload_derivatives()

    check_existing_derivatives()
    return if @derivs_we_need == {}

    @working_dir = Dir.mktmpdir("fileset_#{file_set.id}_", @working_dir_parent)
    @working_original_path = download_file_from_fedora()
    deriv_creation_futures = []
    errors_to_reraise = []
    cmd = TTY::Command.new(printer: :null)
    @derivs_we_need.each do  | deriv_type, properties |
      deriv_local_path = where_to_save_derivative(deriv_type, properties)
      convert_audio_command = convert_command_args(deriv_type, properties, deriv_local_path)

      # START CONCURRENCY
      deriv_creation_futures << Concurrent::Future.execute(executor: Concurrent.global_io_executor) do
        begin
          result = cmd.run(*convert_audio_command)
        rescue TTY::Command::ExitError => ex
          Rails.logger.error ex.message
          errors_to_reraise << ex
          next
        end
        if upload_file_to_s3(deriv_local_path, properties)
          Rails.logger.info "Uploaded derivative to #{properties.s3_obj.public_url}"
        else
          Rails.logger.error "Unable to upload derivative."
          errors_to_reraise << IOError.new("Could not upload derivative  #{deriv_type} to S3 for file #{file_id}")
        end # if upload successful
      end
      # END CONCURRENCY

    end #each

    # EXECUTE CONCURRENT CODE
    deriv_creation_futures.compact.each { |f| f.value!() }

    # The first error prevents the others from being raised;
    # not sure what our goal is for error reporting.
    # TODO make sure at Honeybadger gets notified of
    # at least the first error.
    errors_to_reraise.each { |x| raise x }
  end # method

  # Is this a mimetype that could belong to an audio file?
  def self.is_audio?(file_set_content_type)
    AUDIO_DERIVATIVE_TYPES.values.any?{ |x| file_set_content_type == x.content_type }
  end

  private

  # Figure out which derivs we already have; return a list of the ones we need
  # to create and upload.
  # Side effect: adds a s3_obj to the properties for each needed
  # derivative that can be used to upload the object.
  def check_existing_derivatives()
    @derivs_we_need = {}
    deriv_check_futures = []
    AUDIO_DERIVATIVE_TYPES.each do  | deriv_type, properties |

      # START CONCURRENCY
      deriv_check_futures << Concurrent::Future.execute do
        s3_obj = get_s3_obj_for_derivative(deriv_type, properties)
        if we_need_this_derivative?(s3_obj)
          properties[:s3_obj] = s3_obj
          @derivs_we_need[deriv_type] = properties
        end
      end
      # END CONCURRENCY

    end # audio derivs

    # RUN CONCURRENT CODE:
    deriv_check_futures.compact.each { |f| f.value!() }
  end

  # Generates an S3 object that can be used to upload a particular
  # derivative for this audi file.
  def get_s3_obj_for_derivative(deriv_type, properties)
    the_path = "#{@file_set.id}_checksum#{@file_checksum}/#{Pathname.new(deriv_type.to_s).sub_ext(properties.suffix)}"
    @bucket.object(the_path)
  end

  # Given the ID of a Sufia file, download it from Fedora.
  def download_file_from_fedora()
    CHF::GetFedoraBytestreamService.new(@file_id, local_path: File.join(@working_dir, "original")).get
  end

  # If we're in lazy mode, don't
  # generated derivatives if they
  # already exist.
  def we_need_this_derivative?(s3_obj)
    return true unless @lazy
    return !(s3_obj.exists?)
  end

  # Given a set of derivative properties, returns
  # a path for where to save a derivative.
  def where_to_save_derivative(deriv_type, properties)
    Pathname.new(@working_dir).
      join(deriv_type.to_s).
      sub_ext(properties.suffix).to_s
  end

  # An array of strings that, together, make up
  # a shell command to convert
  # an original audio file to a derivative.
  # Does not actually invoke the command.
  def convert_command_args(deriv_type, properties, deriv_local_path)
    rate_arr = properties.rate  ? ["-ar", properties.rate] : []
    args = [ "ffmpeg",
      "-f", @input_format,
      "-i", @working_original_path ] +
      rate_arr +
      [ deriv_local_path ]
    return args
  end

  # Upload a derivative to s3.
  def upload_file_to_s3 (deriv_local_path, properties)
    result = properties.
      s3_obj.
      upload_file(
        deriv_local_path,
        acl: @acl,
        content_type: properties.content_type,
        content_disposition: "attachment",
        cache_control: @cache_control)
    return result
  end

end # class
end # module