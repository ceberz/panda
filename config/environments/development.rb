Merb.logger.info("Loaded DEVELOPMENT Environment...")
Merb::Config.use { |c|
  c[:exception_details] = true
  c[:reload_classes] = true
  c[:reload_time] = 0.5
  c[:log_auto_flush ] = true
}

PANDA_HOME = File.join(Merb.root, '..', 'panda_ec2', 'panda')
PANDA_LOG_SERVER = "127.0.0.1"
PANDA_DOMAIN = "127.0.0.1"
PANDA_PORT = 4000
PANDA_UPLOAD_DOMAIN = "127.0.0.1"
PANDA_UPLOAD_PORT = 4001
PANDA_VIDEOS_DOMAIN = "videos.pandastream.com"