Merb.logger.info("Loaded PRODUCTION Environment...")
Merb::Config.use { |c|
  c[:exception_details] = false
  c[:reload_classes] = false
  c[:log_level] = :error
  c[:log_file] = Merb.log_path + "/production.log"
}

PANDA_HOME = "/mnt/panda"
PANDA_LOG_SERVER = "127.0.0.1"
PANDA_DOMAIN = "hq.pandastream.com"
PANDA_PORT = 80
PANDA_UPLOAD_DOMAIN = "upload.pandastream.com"
PANDA_UPLOAD_PORT = 80
PANDA_VIDEOS_DOMAIN = "videos.pandastream.com"