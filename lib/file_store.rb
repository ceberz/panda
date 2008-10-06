class FileStore
  include FileUtils
  
  def initialize
    @dir = Panda::Config[:public_videos_dir]
    mkdir_p(@dir)
  end
  
  # Set file. Returns true if success.
  def set(key, tmp_file)
    cp(tmp_file, @dir / key)
    true
  end
  
  # Get file.
  def get(key, tmp_file)
    cp(@dir / key, tmp_file)
  end
  
  # Delete file. Returns true if success.
  def delete(key)
    rm(@dir / key)
  end
  
  # Return the publically accessible URL for the given key
  def url(key)
    %(http://#{Panda::Config[:videos_domain]}/#{key})
  end
end
