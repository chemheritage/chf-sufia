module CHF

# Creates all audio derivatives and uploads them to s3.

# This bypasses and replaces much of the code in the run method of
# CHF::CreateDerivativesOnS3Service, but does borrow a couple of class methods
# and properties from it (search for "CHF::CreateDerivativesOnS3Service" below).
class AudioDerivativeMaker

  # Class method: the URL of the s3 URL for an audio derivative for a given fileset.
  # Bucket and checksum are optional, but pass them in if you have them.
  def self.s3_public_url(file_set, deriv_type, checksum=nil, bucket=nil)
    raise ArgumentError, "Nil fileset passed" unless file_set
    if bucket.nil?
      bucket = CHF::CreateDerivativesOnS3Service.s3_bucket!
    end
    self.s3_obj(bucket, deriv_type, file_set, checksum).public_url
  end

  # Formats we accept as ORIGINALS:
  AUDIO_ORIGINAL_FORMATS = {
    'audio/flac'   => 'flac',
    'audio/x-flac' => 'flac',
    'audio/mpeg'   => 'mp3',  'audio/webm'   => 'webm'
  }

  # DERIVATIVE formats the originals will get converted to:
  AUDIO_DERIVATIVE_FORMATS = {
    standard_webm: OpenStruct.new( suffix: '.webm', content_type: 'audio/webm',
      extra_args: ["-ac", "1", "-codec:a", "libopus", "-b:a", "64k"]),
    standard_mp3:  OpenStruct.new( suffix: '.mp3',  content_type: 'audio/mpeg',
      extra_args: ["-ac", "1", "-b:a", "64k"])
  }

  attr_reader :file_id, :file_set, :mimetype, :file_checksum,
  :bucket, :lazy

  def initialize (file_info, lazy)
    @mimetype =      file_info[:file_set_content_type]
    unless AUDIO_ORIGINAL_FORMATS.include? @mimetype
      raise(ArgumentError, "Can't convert from format #{@mimetype}")
    end
    @file_id =       file_info[:file_id]
    @file_set =      file_info[:file_set]
    @file_checksum = file_info[:file_checksum]
    @lazy =   lazy
    @bucket = CHF::CreateDerivativesOnS3Service.s3_bucket!
  end

  # Do we accept this type of audio file as an original?
  def self.is_audio?(mimetype)
    AUDIO_ORIGINAL_FORMATS.keys.include? mimetype
  end

  # Create and upload all audio derivatives for audio file file_set
  def create_and_upload_derivatives()
    derivs_we_need = check_which_derivs_we_need()
    return if derivs_we_need == {}
    parent_dir = CHF::CreateDerivativesOnS3Service::WORKING_DIR_PARENT
    @working_dir = Dir.mktmpdir("fileset_#{file_set.id}_", parent_dir)
    @working_original_path = download_file_from_fedora()
    deriv_creation_futures = []
    cmd = TTY::Command.new(printer: :null)
    derivs_we_need.each do  | deriv_type, properties |
      deriv_local_path = where_to_save_derivative(deriv_type, properties)
      convert_audio_command = convert_command_args(properties, deriv_local_path)
      # START CONCURRENCY
      deriv_creation_futures << Concurrent::Future.execute(executor: Concurrent.global_io_executor) do
        result = cmd.run(*convert_audio_command)
        if upload_file_to_s3(deriv_local_path, properties)
          report_success(properties)
        else
          raise IOError.new("Could not upload derivative  #{deriv_type} to S3 for file #{file_id}")
        end
      end
      # END CONCURRENCY
    end #each

    # RUN CONCURRENT CODE
    deriv_creation_futures.compact.each { |f| f.value!() }

  end # method

  private

  def report_success(properties)
    Rails.logger.info "Uploaded derivative to #{properties.s3_obj.public_url}"
  end

  # Figure out which derivs we already have; return a list of the ones we need
  # to create and upload.
  # Adds a s3_obj to the properties for each needed
  # derivative that can be used to upload the object.
  def check_which_derivs_we_need()
    result = {}
    deriv_check_futures = []
    AUDIO_DERIVATIVE_FORMATS.each do  | deriv_type, properties |
      # START CONCURRENCY
      deriv_check_futures << Concurrent::Future.execute do
        s3_obj = s3_obj_for_this_file(deriv_type)
        if we_need_this_derivative?(s3_obj)
          properties[:s3_obj] = s3_obj
          result[deriv_type] = properties
        end
      end
      # END CONCURRENCY
    end # audio derivs
    # RUN CONCURRENT CODE:
    deriv_check_futures.compact.each { |f| f.value!() }
    return result
  end

  # Instance method -- s3 object for *this* file_set, given a deriv type.
  def s3_obj_for_this_file(deriv_type)
    self.class.s3_obj(@bucket, deriv_type, @file_set, @file_checksum)
  end

  # Class method: construct a s3 object for any bucket, file_set and deriv type.
  # Pass in the checksum if you already have it; otherwise it'll get looked up.
  def self.s3_obj(bucket, deriv_type, file_set, checksum=nil)
    raise(ArgumentError, "Don't recognize format #{deriv_type.to_s}") unless AUDIO_DERIVATIVE_FORMATS.keys.include? deriv_type
    checksum = file_set.files.first.checksum.value unless checksum
    suffix = AUDIO_DERIVATIVE_FORMATS[deriv_type].suffix
    part_1 = "#{file_set.id}_checksum#{checksum}"
    part_2 = "#{Pathname.new(deriv_type.to_s).sub_ext(suffix)}"
    bucket.object("#{part_1}/#{part_2}")
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
  # a local path where we can save a temporary derivative file
  # which will be uploaded to s3, then deleted.
  def where_to_save_derivative(deriv_type, properties)
    Pathname.new(@working_dir).
      join(deriv_type.to_s).
      sub_ext(properties.suffix).to_s
  end

  # An array of strings that, together, make up
  # a shell command to convert
  # an original audio file to a derivative.
  # Does not actually invoke the command.
  def convert_command_args(properties, deriv_local_path)
    args = [ "ffmpeg",
      "-i", @working_original_path ] +
      properties.extra_args +
      [ deriv_local_path ]
    return args
  end

  # Upload a derivative to s3.
  # Returns true on success, false on failure.
  def upload_file_to_s3 (deriv_local_path, properties)
    properties.s3_obj.upload_file(
      deriv_local_path,
      acl: CHF::CreateDerivativesOnS3Service.acl,
      content_type: properties.content_type,
      content_disposition: "attachment",
      cache_control: CHF::CreateDerivativesOnS3Service.cache_control)
  end

end # class
end # module