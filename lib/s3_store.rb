class S3VideoObject < AWS::S3::S3Object
  set_current_bucket_to Panda::Config[:s3_videos_bucket]
end

class S3Store < AbstractStore
  def initialize
    AWS::S3::Base.establish_connection!(
      :access_key_id     => Panda::Config[:access_key_id],
      :secret_access_key => Panda::Config[:secret_access_key],
      :persistent => false
    )
  end
  
  # Set file. Returns true if success.
  def set(key, tmp_file)
    begin
      retryable(:tries => 5) do
        Merb.logger.info "Upload to S3"
        S3VideoObject.store(key, File.open(tmp_file), :access => :public_read)
        sleep 3
      end
    rescue
      Merb.logger.error "Error uploading #{key} to S3"
      raise
    else
      true
    end
  end
  
  # Get file.
  def get(key, tmp_file)
    begin
      retryable(:tries => 5) do
        File.open(tmp_file, 'w') do |file|
          Merb.logger.info "Fetch from S3"
          S3VideoObject.stream(key) {|chunk| file.write chunk}
        end
        sleep 3
      end
    rescue
      Merb.logger.error "Error fetching #{key} from S3"
      raise
    else
      true
    end
  end
  
  # Delete file. Returns true if success.
  def delete(key)
    begin
      retryable(:tries => 5) do
        Merb.logger.info "Deleting #{key} from S3"
        S3VideoObject.delete(key)
        sleep 3
      end
    rescue
      Merb.logger.error "Error deleting #{key} from S3"
      raise
    else
      true
    end
  end
  
  # Return the publically accessible URL for the given key
  def url(key)
    %(http://#{Panda::Config[:videos_domain]}/#{key})
  end
end
