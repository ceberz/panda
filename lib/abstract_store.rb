class AbstractStore
  def initialize
    raise "Method not implemented. Called abstract class."
  end
  
  # Set file. Returns true if success.
  def set(key, tmp_file)
    raise "Method not implemented. Called abstract class."
  end
  
  # Get file.
  def get(key, tmp_file)
    raise "Method not implemented. Called abstract class."
  end
  
  # Delete file. Returns true if success.
  def delete(key)
    raise "Method not implemented. Called abstract class."
  end
  
  # Return the publically accessible URL for the given key
  def url(key)
    raise "Method not implemented. Called abstract class."
  end
end
