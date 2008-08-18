Merb.logger.info("Loaded ENCODER Environment...")
Merb::Config.use { |c|
  c[:exception_details] = true
  c[:log_auto_flush ] = true
  c[:reload_classes] = false
  c[:log_level] = :info
  c[:log_file] = Merb.log_path + "/encoder.log"
}