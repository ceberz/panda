God.watch do |w|
  w.name = "panda"
  current_path  = "/var/www/panda"
  port = 4001
  w.start = "/bin/bash -c 'cd #{current_path}; merb -d -p #{port} -e production'"
  w.stop = "/bin/bash -c 'cd #{current_path}; merb -k #{port}'"
  w.pid_file = File.join(current_path, "log/merb.#{port}.pid")
  w.behavior(:clean_pid_file)
  w.start_grace = 10.seconds
  w.restart_grace = 10.seconds
  
  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 10.seconds
      c.running = false
      c.notify = 'admin'
    end
  end
end

God.watch do |w|
  w.name = "encoder"
  current_path  = "/var/www/panda"
  port = 4091
  w.start = "/bin/bash -c 'cd #{current_path}; merb -r lib/encoder.rb -d -p #{port} -e production'"
  w.stop = "/bin/bash -c 'cd #{current_path}; merb -k #{port}'"
  w.pid_file = File.join(current_path, "log/merb.#{port}.pid")
  w.behavior(:clean_pid_file)
  w.start_grace = 10.seconds
  w.restart_grace = 10.seconds
  
  w.start_if do |start|
    start.condition(:process_running) do |c|
      c.interval = 10.seconds
      c.running = false
      c.notify = 'admin'
    end
  end
end

God::Contacts::Email.message_settings = {
  :from => 'admin@localhost'
}

God::Contacts::Email.server_settings = {
  :address => "localhost",
  :port => 25,
  :domain => "pandastream.com"
  # :authentication => :plain,
  # :user_name => "john",
  # :password => "s3kr3ts"
}

God.contact(:email) do |c|
  c.name = 'admin'
  c.email = 'admin@localhost'
end